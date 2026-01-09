import 'package:flutter/material.dart';
import '../../core/utils/image_path_utils.dart';

/// A widget that displays pagoda images with automatic path normalization and error handling
class PagodaImageWidget extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  
  const PagodaImageWidget({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
  });
  
  @override
  Widget build(BuildContext context) {
    // Normalize the image path
    final String normalizedPath = ImagePathUtils.normalizeImagePath(imageUrl);
    
    // If path is empty or invalid, show placeholder
    if (normalizedPath.isEmpty || !ImagePathUtils.isValidAssetPath(normalizedPath)) {
      return _buildPlaceholder(context);
    }
    
    return Image.asset(
      normalizedPath,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        print('Image load error for path: $normalizedPath');
        print('Original path: $imageUrl');
        print('Error: $error');
        
        // Try alternative path variations
        final String altPath = _tryAlternativePath(normalizedPath);
        if (altPath != normalizedPath && ImagePathUtils.isValidAssetPath(altPath)) {
          return Image.asset(
            altPath,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (context, error2, stackTrace2) {
              return _buildPlaceholder(context);
            },
          );
        }
        
        return _buildPlaceholder(context);
      },
    );
  }
  
  Widget _buildPlaceholder(BuildContext context) {
    if (placeholder != null) {
      return SizedBox(
        width: width,
        height: height,
        child: placeholder,
      );
    }
    
    return Container(
      width: width,
      height: height,
      color: Colors.grey[300],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.temple_buddhist, size: 60, color: Colors.grey),
          const SizedBox(height: 8),
          Text(
            'Image not found',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
  
  /// Try alternative path variations if the original fails
  String _tryAlternativePath(String path) {
    // Remove "pagodas/pagodas/" if present
    String altPath = path.replaceAll('pagodas/pagodas/', 'pagodas/');
    
    // If path doesn't start with assets/, try adding it
    if (!altPath.startsWith('assets/')) {
      altPath = 'assets/$altPath';
    }
    
    return ImagePathUtils.normalizeImagePath(altPath);
  }
}