from __future__ import annotations

import csv
import heapq
import json
import math
from collections import defaultdict, deque
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "assets" / "data"

PAGODAS_PATH = DATA_DIR / "sample_pagodas.json"
OFFLINE_GRAPH_PATH = DATA_DIR / "offline_graph.json"
TOPOLOGY_PATH = DATA_DIR / "pagoda_route_topology.csv"

GRAPH_OUTPUT_PATH = DATA_DIR / "pagoda_route_graph.json"
NODES_OUTPUT_PATH = DATA_DIR / "pagoda_route_nodes.csv"
EDGES_OUTPUT_PATH = DATA_DIR / "pagoda_route_edges.csv"
PAIRWISE_OUTPUT_PATH = DATA_DIR / "pagoda_pairwise_costs.csv"


@dataclass(frozen=True)
class PagodaRecord:
    pagoda_id: str
    name: str
    lat: float
    lng: float


@dataclass(frozen=True)
class SnappedPagoda:
    pagoda: PagodaRecord
    road_node_id: str
    access_gap_km: float


@dataclass(frozen=True)
class RouteMetrics:
    straight_line_km: float
    road_distance_km: float
    from_access_gap_km: float
    to_access_gap_km: float
    weight: float


def haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    earth_radius_km = 6371.0088
    lat1_rad = math.radians(lat1)
    lat2_rad = math.radians(lat2)
    delta_lat = math.radians(lat2 - lat1)
    delta_lon = math.radians(lon2 - lon1)

    sin_lat = math.sin(delta_lat / 2)
    sin_lon = math.sin(delta_lon / 2)
    arc = (
        sin_lat * sin_lat
        + math.cos(lat1_rad) * math.cos(lat2_rad) * sin_lon * sin_lon
    )
    return earth_radius_km * 2 * math.atan2(math.sqrt(arc), math.sqrt(1 - arc))


def round_km(value: float) -> float:
    return round(value, 6)


def load_pagodas() -> list[PagodaRecord]:
    raw_pagodas = json.loads(PAGODAS_PATH.read_text(encoding="utf-8"))
    pagodas = [
        PagodaRecord(
            pagoda_id=str(item["id"]),
            name=str(item["name"]),
            lat=float(item["latitude"]),
            lng=float(item["longitude"]),
        )
        for item in raw_pagodas
    ]
    pagodas.sort(key=lambda pagoda: pagoda.pagoda_id)
    return pagodas


def load_offline_graph() -> tuple[
    int,
    dict[str, tuple[float, float]],
    dict[str, list[tuple[str, float]]],
    dict[str, set[str]],
]:
    raw_graph = json.loads(OFFLINE_GRAPH_PATH.read_text(encoding="utf-8"))

    node_positions = {
        str(node["id"]): (float(node["lat"]), float(node["lng"]))
        for node in raw_graph["nodes"]
    }

    directed_adjacency: dict[str, list[tuple[str, float]]] = defaultdict(list)
    undirected_neighbors: dict[str, set[str]] = defaultdict(set)

    for edge in raw_graph["edges"]:
        source = str(edge["from"])
        target = str(edge["to"])
        weight = float(edge["weight"])
        one_way = bool(edge.get("oneWay", False))

        directed_adjacency[source].append((target, weight))
        undirected_neighbors[source].add(target)
        undirected_neighbors[target].add(source)

        if not one_way:
            directed_adjacency[target].append((source, weight))

    return (
        int(raw_graph.get("version", 0)),
        node_positions,
        directed_adjacency,
        undirected_neighbors,
    )


def find_largest_component(
    node_positions: dict[str, tuple[float, float]],
    undirected_neighbors: dict[str, set[str]],
) -> set[str]:
    remaining = set(node_positions)
    largest_component: set[str] = set()

    while remaining:
        start = remaining.pop()
        component = {start}
        queue = deque([start])

        while queue:
            current = queue.popleft()
            for neighbor in undirected_neighbors.get(current, ()):
                if neighbor in component:
                    continue
                component.add(neighbor)
                if neighbor in remaining:
                    remaining.remove(neighbor)
                queue.append(neighbor)

        if len(component) > len(largest_component):
            largest_component = component

    return largest_component


def snap_pagodas_to_roads(
    pagodas: list[PagodaRecord],
    node_positions: dict[str, tuple[float, float]],
    eligible_node_ids: set[str],
) -> dict[str, SnappedPagoda]:
    candidate_nodes = [
        (node_id, lat, lng)
        for node_id, (lat, lng) in node_positions.items()
        if node_id in eligible_node_ids
    ]
    snapped: dict[str, SnappedPagoda] = {}

    for pagoda in pagodas:
        best_node_id = ""
        best_gap_km = math.inf
        for node_id, lat, lng in candidate_nodes:
            gap_km = haversine_km(pagoda.lat, pagoda.lng, lat, lng)
            if gap_km < best_gap_km:
                best_gap_km = gap_km
                best_node_id = node_id

        snapped[pagoda.pagoda_id] = SnappedPagoda(
            pagoda=pagoda,
            road_node_id=best_node_id,
            access_gap_km=best_gap_km,
        )

    return snapped


def load_topology(pagodas_by_id: dict[str, PagodaRecord]) -> list[tuple[str, str]]:
    with TOPOLOGY_PATH.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        required_fields = {"from", "fromName", "to", "toName"}
        if set(reader.fieldnames or ()) != required_fields:
            raise ValueError(
                f"Unexpected topology columns: {reader.fieldnames}. "
                f"Expected {sorted(required_fields)}."
            )

        seen_pairs: set[tuple[str, str]] = set()
        topology_pairs: list[tuple[str, str]] = []

        for row in reader:
            source = row["from"].strip()
            target = row["to"].strip()
            if source == target:
                raise ValueError(f"Topology self-edge is not allowed: {source}")
            if source not in pagodas_by_id or target not in pagodas_by_id:
                raise ValueError(f"Unknown pagoda id in topology: {source}, {target}")

            source_name = row["fromName"].strip()
            target_name = row["toName"].strip()
            if source_name and source_name != pagodas_by_id[source].name:
                raise ValueError(
                    f"Topology name mismatch for {source}: {source_name} "
                    f"!= {pagodas_by_id[source].name}"
                )
            if target_name and target_name != pagodas_by_id[target].name:
                raise ValueError(
                    f"Topology name mismatch for {target}: {target_name} "
                    f"!= {pagodas_by_id[target].name}"
                )

            pair_key = tuple(sorted((source, target)))
            if pair_key in seen_pairs:
                raise ValueError(f"Duplicate topology edge: {pair_key}")
            seen_pairs.add(pair_key)
            topology_pairs.append((source, target))

    topology_pairs.sort()
    return topology_pairs


def dijkstra_to_targets(
    adjacency: dict[str, list[tuple[str, float]]],
    source: str,
    target_ids: set[str],
) -> dict[str, float]:
    distances = {source: 0.0}
    queue: list[tuple[float, str]] = [(0.0, source)]
    found = {source: 0.0} if source in target_ids else {}
    remaining = set(target_ids)
    remaining.discard(source)

    while queue and remaining:
        current_distance, current_node = heapq.heappop(queue)
        if current_distance > distances.get(current_node, math.inf):
            continue

        if current_node in remaining:
            found[current_node] = current_distance
            remaining.remove(current_node)

        for neighbor, edge_weight in adjacency.get(current_node, ()):
            next_distance = current_distance + edge_weight
            if next_distance >= distances.get(neighbor, math.inf):
                continue
            distances[neighbor] = next_distance
            heapq.heappush(queue, (next_distance, neighbor))

    if remaining:
        missing_targets = ", ".join(sorted(remaining))
        raise ValueError(
            f"Road graph shortest paths missing from {source} to: {missing_targets}"
        )

    return found


def compute_pairwise_road_distances(
    snapped_pagodas: dict[str, SnappedPagoda],
    adjacency: dict[str, list[tuple[str, float]]],
) -> dict[tuple[str, str], float]:
    unique_road_nodes = sorted(
        {snapped.road_node_id for snapped in snapped_pagodas.values()}
    )
    targets = set(unique_road_nodes)
    road_distances_by_source = {
        road_node_id: dijkstra_to_targets(adjacency, road_node_id, targets)
        for road_node_id in unique_road_nodes
    }

    pairwise_road_distances: dict[tuple[str, str], float] = {}
    for source_id, source_snapped in snapped_pagodas.items():
        source_distances = road_distances_by_source[source_snapped.road_node_id]
        for target_id, target_snapped in snapped_pagodas.items():
            pairwise_road_distances[(source_id, target_id)] = source_distances[
                target_snapped.road_node_id
            ]

    return pairwise_road_distances


def route_metrics_for_pair(
    source: SnappedPagoda,
    target: SnappedPagoda,
    road_distance_km: float,
) -> RouteMetrics:
    straight_line_km = haversine_km(
        source.pagoda.lat,
        source.pagoda.lng,
        target.pagoda.lat,
        target.pagoda.lng,
    )
    weight = road_distance_km + source.access_gap_km + target.access_gap_km

    return RouteMetrics(
        straight_line_km=round_km(straight_line_km),
        road_distance_km=round_km(road_distance_km),
        from_access_gap_km=round_km(source.access_gap_km),
        to_access_gap_km=round_km(target.access_gap_km),
        weight=round_km(weight),
    )


def write_nodes_csv(snapped_pagodas: dict[str, SnappedPagoda]) -> None:
    with NODES_OUTPUT_PATH.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "pagodaId",
                "name",
                "lat",
                "lng",
                "roadNodeId",
                "accessGapKm",
            ],
        )
        writer.writeheader()
        for pagoda_id in sorted(snapped_pagodas):
            snapped = snapped_pagodas[pagoda_id]
            writer.writerow(
                {
                    "pagodaId": pagoda_id,
                    "name": snapped.pagoda.name,
                    "lat": snapped.pagoda.lat,
                    "lng": snapped.pagoda.lng,
                    "roadNodeId": snapped.road_node_id,
                    "accessGapKm": round_km(snapped.access_gap_km),
                }
            )


def write_edges_csv(
    topology_pairs: list[tuple[str, str]],
    snapped_pagodas: dict[str, SnappedPagoda],
    pairwise_road_distances: dict[tuple[str, str], float],
) -> list[dict[str, object]]:
    edge_rows: list[dict[str, object]] = []
    with EDGES_OUTPUT_PATH.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "from",
                "fromName",
                "to",
                "toName",
                "straightLineKm",
                "roadDistanceKm",
                "fromAccessGapKm",
                "toAccessGapKm",
                "weight",
            ],
        )
        writer.writeheader()

        for source_id, target_id in topology_pairs:
            source = snapped_pagodas[source_id]
            target = snapped_pagodas[target_id]
            metrics = route_metrics_for_pair(
                source,
                target,
                pairwise_road_distances[(source_id, target_id)],
            )
            row = {
                "from": source_id,
                "fromName": source.pagoda.name,
                "to": target_id,
                "toName": target.pagoda.name,
                "straightLineKm": metrics.straight_line_km,
                "roadDistanceKm": metrics.road_distance_km,
                "fromAccessGapKm": metrics.from_access_gap_km,
                "toAccessGapKm": metrics.to_access_gap_km,
                "weight": metrics.weight,
            }
            writer.writerow(row)
            edge_rows.append(row)

    return edge_rows


def write_pairwise_csv(
    pagodas: list[PagodaRecord],
    snapped_pagodas: dict[str, SnappedPagoda],
    pairwise_road_distances: dict[tuple[str, str], float],
    topology_pairs: list[tuple[str, str]],
) -> None:
    topology_lookup = {
        tuple(sorted((source_id, target_id))) for source_id, target_id in topology_pairs
    }

    with PAIRWISE_OUTPUT_PATH.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "from",
                "fromName",
                "to",
                "toName",
                "straightLineKm",
                "roadDistanceKm",
                "fromAccessGapKm",
                "toAccessGapKm",
                "weight",
                "topologyEdge",
            ],
        )
        writer.writeheader()

        for source in pagodas:
            for target in pagodas:
                if source.pagoda_id == target.pagoda_id:
                    continue
                snapped_source = snapped_pagodas[source.pagoda_id]
                snapped_target = snapped_pagodas[target.pagoda_id]
                metrics = route_metrics_for_pair(
                    snapped_source,
                    snapped_target,
                    pairwise_road_distances[(source.pagoda_id, target.pagoda_id)],
                )
                writer.writerow(
                    {
                        "from": source.pagoda_id,
                        "fromName": source.name,
                        "to": target.pagoda_id,
                        "toName": target.name,
                        "straightLineKm": metrics.straight_line_km,
                        "roadDistanceKm": metrics.road_distance_km,
                        "fromAccessGapKm": metrics.from_access_gap_km,
                        "toAccessGapKm": metrics.to_access_gap_km,
                        "weight": metrics.weight,
                        "topologyEdge": str(
                            tuple(sorted((source.pagoda_id, target.pagoda_id)))
                            in topology_lookup
                        ).lower(),
                    }
                )


def write_graph_json(
    source_graph_version: int,
    snapped_pagodas: dict[str, SnappedPagoda],
    edge_rows: list[dict[str, object]],
) -> None:
    graph_payload = {
        "version": 1,
        "sourceGraphVersion": source_graph_version,
        "topologySource": TOPOLOGY_PATH.name,
        "pairwiseCostSource": PAIRWISE_OUTPUT_PATH.name,
        "snapStrategy": "nearest_node_in_largest_component",
        "nodes": [
            {
                "pagodaId": pagoda_id,
                "name": snapped_pagodas[pagoda_id].pagoda.name,
                "lat": snapped_pagodas[pagoda_id].pagoda.lat,
                "lng": snapped_pagodas[pagoda_id].pagoda.lng,
                "roadNodeId": snapped_pagodas[pagoda_id].road_node_id,
                "accessGapKm": round_km(snapped_pagodas[pagoda_id].access_gap_km),
            }
            for pagoda_id in sorted(snapped_pagodas)
        ],
        "edges": [
            {
                "from": row["from"],
                "to": row["to"],
                "weight": row["weight"],
                "roadDistanceKm": row["roadDistanceKm"],
            }
            for row in edge_rows
        ],
    }
    GRAPH_OUTPUT_PATH.write_text(
        json.dumps(graph_payload, indent=2),
        encoding="utf-8",
    )


def main() -> None:
    pagodas = load_pagodas()
    pagodas_by_id = {pagoda.pagoda_id: pagoda for pagoda in pagodas}

    (
        source_graph_version,
        node_positions,
        directed_adjacency,
        undirected_neighbors,
    ) = load_offline_graph()
    largest_component = find_largest_component(node_positions, undirected_neighbors)
    snapped_pagodas = snap_pagodas_to_roads(pagodas, node_positions, largest_component)
    topology_pairs = load_topology(pagodas_by_id)
    pairwise_road_distances = compute_pairwise_road_distances(
        snapped_pagodas,
        directed_adjacency,
    )

    write_nodes_csv(snapped_pagodas)
    edge_rows = write_edges_csv(topology_pairs, snapped_pagodas, pairwise_road_distances)
    write_pairwise_csv(
        pagodas,
        snapped_pagodas,
        pairwise_road_distances,
        topology_pairs,
    )
    write_graph_json(source_graph_version, snapped_pagodas, edge_rows)

    max_access_gap_km = max(
        snapped.access_gap_km for snapped in snapped_pagodas.values()
    )
    pairwise_row_count = len(pagodas) * (len(pagodas) - 1)

    print(
        f"Wrote {len(snapped_pagodas)} nodes, {len(edge_rows)} topology edges, "
        f"and {pairwise_row_count} pairwise rows."
    )
    print(f"Topology source: {TOPOLOGY_PATH.name}")
    print(f"Max road access gap: {round_km(max_access_gap_km)} km")


if __name__ == "__main__":
    main()
