import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:dream_community_app/core/api/dio_client.dart';
import 'package:dream_community_app/core/config/api_config.dart';

/// Resilient Network Image widget with in-memory caching, deduplicated in-flight
/// requests, and automatic retry for single-threaded dev servers (e.g. Laragon / PHP CLI).
class DreamNetworkImage extends StatefulWidget {
  final String? imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final int? cacheWidth;
  final int? cacheHeight;
  final Widget Function(BuildContext)? placeholder;
  final BorderRadius? borderRadius;

  const DreamNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.cacheWidth,
    this.cacheHeight,
    this.placeholder,
    this.borderRadius,
  });

  // Shared in-memory cache across the app session
  static final Map<String, Uint8List> _memoryCache = {};
  static final Map<String, Future<Uint8List?>> _inflight = {};

  @override
  State<DreamNetworkImage> createState() => _DreamNetworkImageState();
}

class _DreamNetworkImageState extends State<DreamNetworkImage> {
  Uint8List? _bytes;
  bool _isLoading = false;
  String? _resolvedUrl;

  @override
  void initState() {
    super.initState();
    _resolveAndLoad();
  }

  @override
  void didUpdateWidget(covariant DreamNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _resolveAndLoad();
    }
  }

  void _resolveAndLoad() {
    final raw = widget.imageUrl;
    if (raw == null || raw.trim().isEmpty) {
      setState(() {
        _bytes = null;
        _isLoading = false;
        _resolvedUrl = null;
      });
      return;
    }

    final resolved = ApiConfig.resolveUrl(raw.trim()) ?? raw.trim();
    _resolvedUrl = resolved;

    // Check memory cache first (instant hit)
    if (DreamNetworkImage._memoryCache.containsKey(resolved)) {
      _bytes = DreamNetworkImage._memoryCache[resolved];
      _isLoading = false;
      return;
    }

    _fetchBytes(resolved);
  }

  Future<void> _fetchBytes(String url) async {
    setState(() => _isLoading = true);

    try {
      // Deduplicate simultaneous requests for the same image URL
      var future = DreamNetworkImage._inflight[url];
      if (future == null) {
        future = _loadFromNetwork(url);
        DreamNetworkImage._inflight[url] = future;
      }

      final data = await future;
      DreamNetworkImage._inflight.remove(url);

      if (mounted && _resolvedUrl == url) {
        setState(() {
          _bytes = data;
          _isLoading = false;
        });
      }
    } catch (_) {
      DreamNetworkImage._inflight.remove(url);
      if (mounted && _resolvedUrl == url) {
        setState(() {
          _bytes = null;
          _isLoading = false;
        });
      }
    }
  }

  Future<Uint8List?> _loadFromNetwork(String url) async {
    final candidates = <String>[url];
    if (url.contains(':8001/uploads/')) {
      candidates.add(url.replaceFirst(':8001/uploads/', '/JoeDreamzWeek-Website/joedreamz/public/uploads/'));
    }

    for (final candidate in candidates) {
      for (int attempt = 0; attempt < 2; attempt++) {
        try {
          final response = await DioClient().dio.get<List<int>>(
            candidate,
            options: Options(
              responseType: ResponseType.bytes,
              receiveTimeout: const Duration(seconds: 10),
              sendTimeout: const Duration(seconds: 10),
              headers: const {
                'Connection': 'close',
                'Accept': 'image/*,*/*',
              },
            ),
          );

          if (response.data != null && response.data!.isNotEmpty) {
            final bytes = Uint8List.fromList(response.data!);
            DreamNetworkImage._memoryCache[url] = bytes;
            if (candidate != url) {
              DreamNetworkImage._memoryCache[candidate] = bytes;
            }
            return bytes;
          }
        } catch (e) {
          if (attempt == 0) {
            await Future.delayed(const Duration(milliseconds: 150));
          } else {
            debugPrint('[DREAM IMAGE LOAD FAILED] $candidate: $e');
          }
        }
      }
    }
    return null;
  }

  Widget _buildPlaceholder(BuildContext context) {
    if (widget.placeholder != null) {
      return widget.placeholder!(context);
    }
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.white.withValues(alpha: 0.02),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (_bytes != null) {
      content = Image.memory(
        _bytes!,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        cacheWidth: widget.cacheWidth,
        cacheHeight: widget.cacheHeight,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(context),
      );
    } else if (_isLoading) {
      content = _buildPlaceholder(context);
    } else if (_resolvedUrl != null && _resolvedUrl!.isNotEmpty) {
      // Fallback to Image.network if byte fetch yielded nothing
      content = Image.network(
        _resolvedUrl!,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        cacheWidth: widget.cacheWidth,
        cacheHeight: widget.cacheHeight,
        headers: const {'Connection': 'close'},
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) return child;
          return _buildPlaceholder(context);
        },
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(context),
      );
    } else {
      content = _buildPlaceholder(context);
    }

    if (widget.borderRadius != null) {
      return ClipRRect(
        borderRadius: widget.borderRadius!,
        child: content,
      );
    }

    return content;
  }
}
