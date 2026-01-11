/// Utility class for normalizing and fixing image paths
class ImagePathUtils {
  /// Normalizes image paths by removing duplicate "pagodas" directories
  /// and ensuring correct asset path format
  static String normalizeImagePath(String path) {
    if (path.isEmpty) return path;
    
    // Normalize separators early so prefix checks are reliable.
    String normalized = path.replaceAll('\\', '/');

    // Remove any leading slashes that can break asset lookups.
    normalized = normalized.replaceAll(RegExp(r'^/+'), '');

    // Remove duplicate "pagodas/pagodas/" pattern
    normalized = normalized.replaceAll('pagodas/pagodas/', 'pagodas/');

    // Add assets prefix for common relative forms.
    if (!normalized.startsWith('assets/')) {
      if (normalized.startsWith('images/')) {
        normalized = 'assets/$normalized';
      } else if (normalized.startsWith('pagodas/')) {
        normalized = 'assets/images/$normalized';
      }
    }
    
    // Remove any duplicate slashes
    normalized = normalized.replaceAll(RegExp(r'/+'), '/');
    
    return normalized;
  }
  
  /// Gets a placeholder image path if the provided path is invalid
  static String getPlaceholderPath() {
    return 'assets/images/placeholder.png';
  }
  
  /// Checks if a path appears to be a valid asset path
  static bool isValidAssetPath(String path) {
    if (path.isEmpty) return false;
    return path.startsWith('assets/');
  }
}
