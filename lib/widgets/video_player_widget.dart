import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chewie/chewie.dart';
import 'package:chewie/src/material/widgets/playback_speed_dialog.dart';
import 'package:video_player/video_player.dart';
import 'package:pip/pip.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final double aspectRatio;
  final VoidCallback? onBackPressed;
  final Function(VideoPlayerWidgetController)? onControllerCreated;
  final VoidCallback? onReady;
  final VoidCallback? onNextEpisode;
  final VoidCallback? onVideoCompleted;
  final VoidCallback? onPause;
  final VoidCallback? onPlay;

  const VideoPlayerWidget({
    super.key,
    required this.videoUrl,
    this.aspectRatio = 16 / 9,
    this.onBackPressed,
    this.onControllerCreated,
    this.onReady,
    this.onNextEpisode,
    this.onVideoCompleted,
    this.onPause,
    this.onPlay,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

/// VideoPlayerWidget 的控制器，用于外部控制播放器
class VideoPlayerWidgetController {
  final _VideoPlayerWidgetState _state;
  
  VideoPlayerWidgetController._(this._state);
  
  /// 动态更新视频播放 URL
  Future<void> updateVideoUrl(String newVideoUrl, {Duration? startAt}) async {
    await _state.updateVideoUrl(newVideoUrl, startAt: startAt);
  }
  
  /// 跳转到指定进度
  /// [position] 目标位置（秒）
  Future<void> seekTo(Duration position) async {
    await _state.seekTo(position);
  }
  
  /// 获取当前播放位置
  Duration? get currentPosition {
    return _state._videoController?.value.position;
  }
  
  /// 获取视频总时长
  Duration? get duration {
    return _state._videoController?.value.duration;
  }
  
  /// 获取播放状态
  bool get isPlaying {
    return _state._videoController?.value.isPlaying ?? false;
  }

  /// 暂停播放
  void pause() {
    _state._chewieController?.pause();
  }

  /// 添加视频播放进度监听器
  void addProgressListener(VoidCallback listener) {
    _state._addProgressListener(listener);
  }

  /// 移除视频播放进度监听器
  void removeProgressListener(VoidCallback listener) {
    _state._removeProgressListener(listener);
  }

  /// 启动 PiP 模式
  Future<void> startPip() async {
    await _state._startPip();
  }

  /// 停止 PiP 模式
  Future<void> stopPip() async {
    await _state._stopPip();
  }

  /// 检查是否支持 PiP
  bool get isPipSupported => _state._isPipSupported;

  /// 检查 PiP 是否激活
  bool get isPipActive => _state._isPipActive;

  /// 销毁播放器资源
  void dispose() {
    _state._videoController?.dispose();
    _state._chewieController?.dispose();
  }
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> with WidgetsBindingObserver {
  bool _isInitialized = false;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isFullscreen = false;
  bool _hasCompleted = false; // 防止重复触发完成事件
  final List<VoidCallback> _progressListeners = []; // 进度监听器列表
  double _cachedPlaybackSpeed = 1.0; // 暂存的播放速率
  
  // PiP 相关
  final Pip _pip = Pip();
  bool _isPipSupported = false;
  bool _isPipActive = false;
  final ValueNotifier<bool> _pipStateNotifier = ValueNotifier<bool>(false);
  

  @override
  void initState() {
    super.initState();
    // 添加应用生命周期观察者
    WidgetsBinding.instance.addObserver(this);
    
    // 设置初始屏幕方向为竖屏 
    _setPortraitOrientation();
    
    // 初始化 PiP 功能
    _initializePip();
    
    // 创建控制器并通知父组件
    widget.onControllerCreated?.call(VideoPlayerWidgetController._(this));
  }

  // 设置竖屏方向
  void _setPortraitOrientation() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  // 设置横屏方向
  void _setLandscapeOrientation() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  // 恢复屏幕方向为自动
  void _restoreOrientation() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  // 初始化 PiP 功能
  Future<void> _initializePip() async {
    try {
      // 检查设备是否支持 PiP
      _isPipSupported = await _pip.isSupported();

      if (Platform.isIOS) {
        _isPipSupported = false;
      }

      debugPrint('PiP supported: $_isPipSupported');
      
      if (_isPipSupported) {
        // 注册 PiP 状态变化监听器
        await _pip.registerStateChangedObserver(
          PipStateChangedObserver(
            onPipStateChanged: (state, error) {
              if (!mounted) return;
              
              setState(() {
                switch (state) {
                  case PipState.pipStateStarted:
                    _isPipActive = true;
                    _pipStateNotifier.value = true;
                    break;
                  case PipState.pipStateStopped:
                    _isPipActive = false;
                    _pipStateNotifier.value = false;
                    break;
                  case PipState.pipStateFailed:
                    _isPipActive = false;
                    _pipStateNotifier.value = false;
                    debugPrint('PiP failed: $error');
                    break;
                }
              });
            },
          ),
        );
        
        // 配置 PiP 选项
        await _setupPipOptions();
      }
    } catch (e) {
      debugPrint('Error initializing PiP: $e');
    }
  }

  // 设置 PiP 选项
  Future<void> _setupPipOptions() async {
    try {
      PipOptions options;
      
      if (Platform.isAndroid) {
        options = PipOptions(
          autoEnterEnabled: true,
          aspectRatioX: 16,
          aspectRatioY: 9,
          sourceRectHintLeft: 0,
          sourceRectHintTop: 0,
          sourceRectHintRight: 1080,
          sourceRectHintBottom: 720,
          seamlessResizeEnabled: true,
        );
      } else if (Platform.isIOS) {
        options = PipOptions(
          autoEnterEnabled: true,
          preferredContentWidth: 480,
          preferredContentHeight: 270,
          controlStyle: 2, // 隐藏播放暂停按钮和进度条
        );
      } else {
        options = PipOptions(
          autoEnterEnabled: true,
        );
      }
      
      await _pip.setup(options);
    } catch (e) {
      debugPrint('Error setting up PiP options: $e');
    }
  }

  // 启动 PiP 模式
  Future<void> _startPip() async {
    if (!_isPipSupported || _isPipActive || _videoController == null || !_videoController!.value.isInitialized) {
      return;
    }
    
    try {
      // 在进入 PiP 前强制开始播放
      if (!_videoController!.value.isPlaying) {
        await _videoController!.play();
      }
      
      final success = await _pip.start();
      if (!success) {
        debugPrint('Failed to start PiP mode');
      }
    } catch (e) {
      debugPrint('Error starting PiP: $e');
    }
  }

  // 停止 PiP 模式
  Future<void> _stopPip() async {
    if (!_isPipActive) return;
    
    try {
      await _pip.stop();
    } catch (e) {
      debugPrint('Error stopping PiP: $e');
    }
  }

  /// 动态更新视频播放 URL
  /// [newVideoUrl] 新的视频 URL
  /// [startAt] 开始播放时间，如果提供则从指定时间开始播放
  Future<void> updateVideoUrl(String newVideoUrl, {Duration? startAt}) async {
    if (!mounted) return;
    if (newVideoUrl.isEmpty) return;
    
    // 保存当前全屏状态和播放速率
    final wasFullscreen = _isFullscreen;
    if (_videoController != null && _videoController!.value.isInitialized) {
      _cachedPlaybackSpeed = _videoController!.value.playbackSpeed;
    }
    
    // 如果当前在全屏状态，先退出全屏
    if (wasFullscreen && _chewieController != null) {
      _chewieController!.exitFullScreen();
      // 等待退出全屏完成
      await Future.delayed(const Duration(milliseconds: 300));
    }
    
    try {
      // 先移除监听器，再释放控制器
      _videoController?.removeListener(_onVideoStateChanged);
      _chewieController?.dispose();
      _videoController?.dispose();
      
      // 重置状态
      setState(() {
        _isInitialized = false;
        _hasCompleted = false;
        _isFullscreen = false; // 确保全屏状态被重置
      });
      
      // 创建新的控制器
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(newVideoUrl),
      );
      
      await _videoController!.initialize();
      
      if (mounted) {
        _chewieController = ChewieController(
          videoPlayerController: _videoController!,
          autoPlay: true,
          looping: false,
          allowFullScreen: true,
          allowMuting: true,
          allowPlaybackSpeedChanging: true,
          showOptions: true,
          showControlsOnInitialize: true,
          startAt: startAt,
          customControls: CustomChewieControls(
            onBackPressed: widget.onBackPressed,
            onFullscreenChange: _handleFullscreenChange,
            onNextEpisode: widget.onNextEpisode,
            onPause: widget.onPause,
            onPlay: widget.onPlay,
            playerController: VideoPlayerWidgetController._(this),
            pipStateNotifier: _pipStateNotifier,
          ),
        );

        // 恢复播放速率
        _videoController!.setPlaybackSpeed(_cachedPlaybackSpeed);
        
        // 添加视频播放完成监听
        _videoController!.addListener(_onVideoStateChanged);
        
        setState(() {
          _isInitialized = true;
        });
        
        // 触发 ready 事件
        widget.onReady?.call();
        
        // 如果之前是全屏状态，等待 ready 后重新进入全屏
        if (wasFullscreen) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _chewieController != null) {
              // 延迟一点时间确保播放器完全准备好
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted && _chewieController != null) {
                  _chewieController!.enterFullScreen();
                }
              });
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error updating video URL: $e');
      // 如果更新失败，保持当前状态
      setState(() {
        _isInitialized = false;
      });
    }
  }

  /// 跳转到指定进度
  /// [position] 目标位置
  Future<void> seekTo(Duration position) async {
    if (!mounted || _videoController == null || !_videoController!.value.isInitialized) {
      return;
    }
    
    try {
      await _videoController!.seekTo(position);
    } catch (e) {
      debugPrint('Error seeking to position: $e');
    }
  }

  // 处理视频状态变化
  void _onVideoStateChanged() {
    if (!mounted || _videoController == null || !_videoController!.value.isInitialized) return;
    
    final value = _videoController!.value;
    
    // 触发进度监听器
    for (final listener in _progressListeners) {
      try {
        listener();
      } catch (e) {
        debugPrint('Progress listener error: $e');
      }
    }
    
    // 检查视频是否播放完成
    if (value.position >= value.duration && value.duration.inMilliseconds > 0) {
      if (!_hasCompleted) {
        _hasCompleted = true;
        widget.onVideoCompleted?.call();
      }
    }
  }

  /// 添加进度监听器
  void _addProgressListener(VoidCallback listener) {
    if (!_progressListeners.contains(listener)) {
      _progressListeners.add(listener);
    }
  }

  /// 移除进度监听器
  void _removeProgressListener(VoidCallback listener) {
    _progressListeners.remove(listener);
  }


  // 处理全屏状态变化
  void _handleFullscreenChange(bool isFullscreen) {
    if (_isFullscreen != isFullscreen) {
      setState(() {
        _isFullscreen = isFullscreen;
      });
      
      // 根据全屏状态设置屏幕方向
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (isFullscreen) {
          // 进入全屏时根据视频分辨率判断屏幕方向
          _setOrientationBasedOnVideo();
        } else {
          // 退出全屏时强制进入竖屏
          _setPortraitOrientation();
        }
      });
    }
  }

  // 根据视频分辨率设置屏幕方向
  void _setOrientationBasedOnVideo() {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      // 如果视频未初始化，默认使用横屏
      _setLandscapeOrientation();
      return;
    }

    final videoSize = _videoController!.value.size;
    final aspectRatio = videoSize.width / videoSize.height;
    
    // 判断是否为竖屏视频（宽高比小于1）
    if (aspectRatio < 1.0) {
      // 竖屏视频，设置竖屏方向
      _setPortraitOrientation();
    } else {
      // 横屏视频，设置横屏方向
      _setLandscapeOrientation();
    }
  }

  // 应用生命周期变化处理
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (!_isPipSupported || _videoController == null || !_videoController!.value.isInitialized) {
      return;
    }
    
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        // 应用进入后台时启动 PiP（如果视频正在播放）
        if (_videoController!.value.isPlaying && !_isPipActive) {
          _startPip();
        }
        break;
      case AppLifecycleState.resumed:
        // 应用回到前台时停止 PiP
        if (_isPipActive) {
          _stopPip();
        }
        break;
      case AppLifecycleState.detached:
        // 应用被销毁时停止 PiP
        if (_isPipActive) {
          _stopPip();
        }
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  void dispose() {
    // 移除应用生命周期观察者
    WidgetsBinding.instance.removeObserver(this);
    
    // 停止 PiP 并释放资源
    if (_isPipActive) {
      _stopPip();
    }
    _pip.unregisterStateChangedObserver();
    _pip.dispose();
    
    // 释放 ValueNotifier
    _pipStateNotifier.dispose();
    
    // 恢复屏幕方向为自动
    _restoreOrientation();
    // 清理进度监听器
    _progressListeners.clear();
    // 移除监听器
    _videoController?.removeListener(_onVideoStateChanged);
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: Container(
        color: Colors.black,
        child: _isInitialized && _chewieController != null
            ? Chewie(controller: _chewieController!)
            : const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}

class CustomChewieControls extends StatefulWidget {
  final VoidCallback? onBackPressed;
  final Function(bool) onFullscreenChange;
  final VoidCallback? onNextEpisode;
  final VoidCallback? onPause;
  final VoidCallback? onPlay;
  final VideoPlayerWidgetController? playerController;
  final ValueNotifier<bool>? pipStateNotifier;

  const CustomChewieControls({
    super.key,
    this.onBackPressed,
    required this.onFullscreenChange,
    this.onNextEpisode,
    this.onPause,
    this.onPlay,
    this.playerController,
    this.pipStateNotifier,
  });

  @override
  State<CustomChewieControls> createState() => _CustomChewieControlsState();
}

class _CustomChewieControlsState extends State<CustomChewieControls> {
  Timer? _hideTimer;
  bool _controlsVisible = true;
  Size? _screenSize; // 缓存屏幕尺寸
  ChewieController? _chewieController;
  bool _lastPlayingState = false; // 记录上次的播放状态，避免重复触发

  bool _isLongPressing = false;
  double _originalPlaybackSpeed = 1.0;

  @override
  void initState() {
    super.initState();
    // 监听 PiP 状态变化
    widget.pipStateNotifier?.addListener(_onPipStateChanged);
    // 延迟启动定时器，确保控制器已经初始化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _forceStartHideTimer();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 在didChangeDependencies中安全地获取屏幕尺寸
    _screenSize = MediaQuery.of(context).size;
    
    // 获取 ChewieController
    final chewieController = ChewieController.of(context);
    
    // 如果控制器发生变化，先移除旧监听器
    if (_chewieController != null && _chewieController != chewieController) {
      _chewieController!.videoPlayerController.removeListener(_onVideoStateChanged);
    }
    
    _chewieController = chewieController;
    
    // 添加视频状态变化监听器
    if (_chewieController != null) {
      _chewieController!.videoPlayerController.addListener(_onVideoStateChanged);
    }
  }


  void _onVideoStateChanged() {
    // 检查widget是否仍然mounted
    if (!mounted) return;
    
    final isPlaying = _chewieController?.videoPlayerController.value.isPlaying ?? false;
    
    // 只在播放状态真正改变时才处理，避免频繁触发
    if (isPlaying != _lastPlayingState) {
      _lastPlayingState = isPlaying;
      
      // 长按期间不处理自动隐藏逻辑
      if (_isLongPressing) return;
      
      if (isPlaying) {
        // 视频开始播放时，如果控件可见则启动定时器
        if (_controlsVisible) {
          _startHideTimer();
        }
      } else {
        // 视频暂停时，停止定时器并显示控件
        _hideTimer?.cancel();
        if (!_controlsVisible) {
          setState(() {
            _controlsVisible = true;
          });
        }
      }
    }
    
    // 如果视频正在播放且控件可见但没有定时器在运行，启动定时器
    if (isPlaying && _controlsVisible && _hideTimer == null) {
      _startHideTimer();
    }
  }

  void _onLongPressStart(LongPressStartDetails details) {
    final chewieController = _chewieController;
    if (chewieController == null || !chewieController.videoPlayerController.value.isPlaying) {
      return;
    }

    // 停止自动隐藏定时器
    _hideTimer?.cancel();

    setState(() {
      _isLongPressing = true;
      _originalPlaybackSpeed = chewieController.videoPlayerController.value.playbackSpeed;
      chewieController.videoPlayerController.setPlaybackSpeed(3.0);
      _controlsVisible = true;
    });
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    final chewieController = _chewieController;
    if (chewieController == null || !_isLongPressing) {
      return;
    }

    setState(() {
      _isLongPressing = false;
      chewieController.videoPlayerController.setPlaybackSpeed(_originalPlaybackSpeed);
      _controlsVisible = true;
    });
    
    // 长按结束后重新启动自动隐藏定时器
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    // 移除 PiP 状态监听器
    widget.pipStateNotifier?.removeListener(_onPipStateChanged);
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    // 只在视频播放时启动自动隐藏定时器
    if (_chewieController != null && _chewieController!.videoPlayerController.value.isPlaying) {
      _hideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _controlsVisible = false;
          });
        }
      });
    }
  }
  
  // 强制启动隐藏定时器（用于初始化时）
  void _forceStartHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _controlsVisible = false;
        });
      }
    });
  }

  void _onUserInteraction() {
    // 用户交互时始终显示控件并重置定时器
    setState(() {
      _controlsVisible = true;
    });
    _startHideTimer();
    // 强制触发一次UI更新
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _onBlankAreaTap() {
    // 检查widget是否仍然mounted
    if (!mounted) return;
    
    // 点击空白区域时切换控件显示状态
    setState(() {
      _controlsVisible = !_controlsVisible;
    });
    
    if (_controlsVisible) {
      _startHideTimer();
      // 强制触发一次UI更新
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });
    } else {
      _hideTimer?.cancel();
    }
  }

  void _onSeekStart() {
    if (!mounted) return;
    setState(() {
      _controlsVisible = true;
    });
    _hideTimer?.cancel();
    // 拖拽开始也是用户交互，需要重置定时器
    _startHideTimer();
  }

  void _onSeekEnd() {
    _startHideTimer();
  }

  /// 处理 PiP 状态变化
  void _onPipStateChanged() {
    if (!mounted) return;
    
    final isPipActive = widget.pipStateNotifier?.value ?? false;
    if (isPipActive) {
      // 进入 PiP 时隐藏控件
      setState(() {
        _controlsVisible = false;
      });
      _hideTimer?.cancel();
    } else {
      // 退出 PiP 时显示控件
      setState(() {
        _controlsVisible = true;
      });
      _startHideTimer();
    }
  }


  // 退出全屏
  void _exitFullscreen() {
    // 检查widget是否仍然mounted
    if (!mounted) return;
    
    // 退出全屏，屏幕方向会在_handleFullscreenChange中处理
    _chewieController?.exitFullScreen();
    
    // 通知父组件全屏状态变化
    widget.onFullscreenChange(false);
  }

  @override
  Widget build(BuildContext context) {
    final chewieController = ChewieController.of(context);
    final isFullscreen = chewieController.isFullScreen;
    
    return GestureDetector(
      onLongPressStart: _onLongPressStart,
      onLongPressEnd: _onLongPressEnd,
      onLongPressCancel: () {
        if (_isLongPressing) {
          _onLongPressEnd(const LongPressEndDetails());
        }
      },
      child: Stack(
        children: [
          // 全屏点击区域 - 始终存在，用于显示/隐藏控件
          // 排除进度条区域，避免点击冲突
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 0, // 非全屏时排除底部50px区域（进度条+按钮区域）
            child: GestureDetector(
              onTap: _onBlankAreaTap,
              behavior: HitTestBehavior.opaque,
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),
          // 全屏渐变效果
          if (_controlsVisible)
            Positioned.fill(
              child: GestureDetector(
                onTap: _onBlankAreaTap,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.5), // 顶部黑色
                        Colors.transparent, // 中间无色
                        Colors.black.withOpacity(0.1), // 底部黑色
                      ],
                      stops: const [0.0, 0.5, 1.0], // 控制渐变位置
                    ),
                  ),
                ),
              ),
            ),
          // 返回按钮
          if (_controlsVisible)
            Positioned(
              top: isFullscreen ? 8 : 4,
              left: isFullscreen ? 16.0 : 8.0,
              child: GestureDetector(
                onTap: () async {
                  _onUserInteraction();
                  // 如果处于全屏状态，则退出全屏
                  if (isFullscreen) {
                    _exitFullscreen();
                  } else {
                    // 否则调用父组件的返回回调
                    widget.onBackPressed?.call();
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.arrow_back, 
                    color: Colors.white,
                    size: isFullscreen ? 24 : 20,
                  ),
                ),
              ),
            ),
          // 居中播放按钮
          if (_controlsVisible)
            Positioned(
              top: isFullscreen && _screenSize != null
                  ? _screenSize!.height / 2 - 32 // 全屏时使用屏幕中心
                  : 0, // 非全屏时从顶部开始
              bottom: isFullscreen
                  ? null // 全屏时不设置bottom
                  : 0, // 非全屏时从底部开始，配合top=0实现垂直居中
              left: 0,
              right: 0,
              child: Center(
                child: _isLongPressing
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            '3x',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.fast_forward,
                            color: Colors.white,
                            size: isFullscreen ? 64 : 48,
                          ),
                        ],
                      )
                    : GestureDetector(
                        onTap: () {
                          _onUserInteraction();
                          if (chewieController
                              .videoPlayerController.value.isPlaying) {
                            chewieController.pause();
                            widget.onPause?.call();
                          } else {
                            chewieController.play();
                            widget.onPlay?.call();
                          }
                        },
                        child: AnimatedBuilder(
                          animation: chewieController.videoPlayerController,
                          builder: (context, child) {
                            return Icon(
                              chewieController
                                      .videoPlayerController.value.isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              color: Colors.white,
                              size: isFullscreen ? 64 : 48,
                            );
                          },
                        ),
                      ),
              ),
            ),
          // 进度条
          if (_controlsVisible)
            Positioned(
              bottom: isFullscreen ? 58.0 : 42.0,
              left: 0,
              right: 0,
              child: Container(
                height: 12,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: MaterialVideoProgressBar(
                  chewieController.videoPlayerController,
                  barHeight: 6,
                  handleHeight: 6,
                  colors: ChewieProgressColors(
                    playedColor: Colors.red,
                    handleColor: Colors.red,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    bufferedColor: Colors.transparent,
                  ),
                  onDragStart: _onSeekStart,
                  onDragEnd: _onSeekEnd,
                  onDragUpdate: () {
                    // 拖拽过程中保持控件可见并重置定时器
                    if (!_controlsVisible) {
                      setState(() {
                        _controlsVisible = true;
                      });
                    }
                    // 拖拽过程中重置定时器，避免在拖拽时自动隐藏
                    _hideTimer?.cancel();
                  },
                ),
              ),
            ),
          // 底部控件
          if (_controlsVisible)
            Positioned(
              bottom: isFullscreen ? 0 : -12,
              left: 0,
              right: 0,
              child: GestureDetector(
                onTap: () {
                  // 阻止点击事件冒泡到空白区域
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: isFullscreen ? 16.0 : 8.0,
                      right: isFullscreen ? 16.0 : 8.0,
                      top: isFullscreen ? 0.0 : 0.0,
                      bottom: isFullscreen ? 8.0 : 10.0,
                    ),
                    child: Row(
                      children: [
                        // 播放按钮
                        GestureDetector(
                          onTap: () {
                            _onUserInteraction();
                            if (chewieController.videoPlayerController.value.isPlaying) {
                              chewieController.pause();
                              widget.onPause?.call();
                            } else {
                              chewieController.play();
                              widget.onPlay?.call();
                            }
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            child: AnimatedBuilder(
                              animation: chewieController.videoPlayerController,
                              builder: (context, child) {
                                return Icon(
                                  chewieController.videoPlayerController.value.isPlaying
                                      ? Icons.pause
                                      : Icons.play_arrow,
                                  color: Colors.white,
                                  size: isFullscreen ? 28 : 24,
                                );
                              },
                            ),
                          ),
                        ),
                        // 下一集按钮
                        Transform.translate(
                          offset: const Offset(-8, 0),
                          child: GestureDetector(
                            onTap: () {
                              _onUserInteraction();
                              widget.onNextEpisode?.call();
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                Icons.skip_next,
                                color: Colors.white,
                                size: isFullscreen ? 28 : 24,
                              ),
                            ),
                          ),
                        ),
                        // 位置指示器
                        Expanded(
                          child: _buildPositionIndicator(chewieController),
                        ),
                        // PiP button
                        if (widget.playerController?.isPipSupported == true)
                          IconButton(
                            icon: Icon(
                              widget.playerController?.isPipActive == true 
                                  ? Icons.picture_in_picture_alt_outlined 
                                  : Icons.picture_in_picture_alt,
                              color: widget.playerController?.isPipActive == true 
                                  ? Colors.red 
                                  : Colors.white,
                              size: isFullscreen ? 22 : 20,
                            ),
                            onPressed: () async {
                              _onUserInteraction();
                              if (widget.playerController?.isPipActive == true) {
                                await widget.playerController?.stopPip();
                              } else {
                                await widget.playerController?.startPip();
                              }
                            },
                          ),
                        // 倍速按钮
                        IconButton(
                          icon: Icon(
                            Icons.speed,
                            color: Colors.white,
                            size: isFullscreen ? 22 : 20,
                          ),
                          onPressed: () async {
                            _onUserInteraction();
                            final videoController = chewieController.videoPlayerController;
                            final chosenSpeed = await showModalBottomSheet<double>(
                              context: context,
                              isScrollControlled: true,
                              useRootNavigator: chewieController.useRootNavigator,
                              builder:
                                  (context) => PlaybackSpeedDialog(
                                    speeds: const [0.5, 0.75, 1.0, 1.5, 2.0, 3.0],
                                    selected: videoController.value.playbackSpeed,
                                  ),
                            );
                            if (chosenSpeed != null) {
                              videoController.setPlaybackSpeed(chosenSpeed);
                            }
                          },
                        ),
                        // 全屏按钮
                        GestureDetector(
                          onTap: () {
                            _onUserInteraction();
                            if (isFullscreen) {
                              _exitFullscreen();
                            } else {
                              chewieController.enterFullScreen();
                              widget.onFullscreenChange(true);
                            }
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                              color: Colors.white,
                              size: isFullscreen ? 28 : 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPositionIndicator(ChewieController chewieController) {
    final videoPlayerController = chewieController.videoPlayerController;
    
    return AnimatedBuilder(
      animation: videoPlayerController,
      builder: (context, child) {
        final currentPosition = videoPlayerController.value.position;
        final totalDuration = videoPlayerController.value.duration;
        
        return Text(
          '${_formatDuration(currentPosition)} / ${_formatDuration(totalDuration)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    } else {
      return '${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
  }
}