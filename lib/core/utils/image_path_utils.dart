/// Utility class for normalizing and fixing image paths
class ImagePathUtils {
  /// Normalizes image paths by removing duplicate "pagodas" directories
  /// and ensuring correct asset path format
  static String normalizeImagePath(String path) {
    if (path.isEmpty) return path;
    
    // Remove duplicate "pagodas/pagodas/" pattern
    String normalized = path.replaceAll('pagodas/pagodas/', 'pagodas/');
    
    // Ensure path starts with "assets/" if it's an asset path
    if (normalized.startsWith('assets/')) {
      // Remove any leading slashes that might cause issues
      normalized = normalized.replaceAll(RegExp(r'^/+'), '');
    }
    
    // Fix Windows-style backslashes to forward slashes
    normalized = normalized.replaceAll('\\', '/');
    
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