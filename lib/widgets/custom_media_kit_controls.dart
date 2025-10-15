import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'pc_video_player_widget.dart';
import 'dlna_device_dialog.dart';

// 带 hover 效果的按钮组件
class HoverButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final EdgeInsets padding;

  const HoverButton({
    super.key,
    required this.child,
    required this.onTap,
    this.padding = const EdgeInsets.all(8),
  });

  @override
  State<HoverButton> createState() => _HoverButtonState();
}

class _HoverButtonState extends State<HoverButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: widget.padding,
          decoration: _isHovering
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.withValues(alpha: 0.5),
                )
              : null,
          child: widget.child,
        ),
      ),
    );
  }
}

class CustomMediaKitControls extends StatefulWidget {
  final VideoState state;
  final Player player;
  final VoidCallback? onBackPressed;
  final VoidCallback? onNextEpisode;
  final VoidCallback? onPause;
  final PcVideoPlayerWidgetController? playerController;
  final String videoUrl;
  final bool isLastEpisode;
  final bool isLoadingVideo;
  final Function(dynamic)? onCastStarted;
  final String? videoTitle;
  final int? currentEpisodeIndex;
  final int? totalEpisodes;
  final String? sourceName;
  final Function(bool isFullscreen)? onDLNAButtonPressed;

  const CustomMediaKitControls({
    super.key,
    required this.state,
    required this.player,
    this.onBackPressed,
    this.onNextEpisode,
    this.onPause,
    this.playerController,
    required this.videoUrl,
    this.isLastEpisode = false,
    this.isLoadingVideo = false,
    this.onCastStarted,
    this.videoTitle,
    this.currentEpisodeIndex,
    this.totalEpisodes,
    this.sourceName,
    this.onDLNAButtonPressed,
  });

  @override
  State<CustomMediaKitControls> createState() => _CustomMediaKitControlsState();
}

class _CustomMediaKitControlsState extends State<CustomMediaKitControls> {
  Timer? _hideTimer;
  bool _controlsVisible = true;
  Size? _screenSize;
  bool _isLongPressing = false;
  double _originalPlaybackSpeed = 1.0;
  Duration? _dragPosition;
  bool _isSeekingViaSwipe = false;
  double _swipeStartX = 0;
  Duration _swipeStartPosition = Duration.zero;
  StreamSubscription? _playingSubscription;
  StreamSubscription? _positionSubscription;
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    _setupPlayerListeners();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _forceStartHideTimer();
      }
    });
  }

  void _setupPlayerListeners() {
    _playingSubscription = widget.player.stream.playing.listen((playing) {
      if (!mounted) return;

      if (playing) {
        if (_controlsVisible && !_isLongPressing) {
          _startHideTimer();
        }
      } else {
        _hideTimer?.cancel();
        if (!_controlsVisible) {
          setState(() {
            _controlsVisible = true;
          });
        }
      }
    });

    // 监听播放位置变化，实时更新进度指示器
    _positionSubscription = widget.player.stream.position.listen((_) {
      if (mounted && _controlsVisible && !_isSeekingViaSwipe) {
        setState(() {});
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _screenSize = MediaQuery.of(context).size;
  }

  @override
  void didUpdateWidget(CustomMediaKitControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当 widget 更新时，尝试同步全屏状态
    // 使用 try-catch 避免在不安全的时机访问 InheritedWidget
    try {
      final actualFullscreen = widget.state.isFullscreen();
      if (_isFullscreen != actualFullscreen) {
        setState(() {
          _isFullscreen = actualFullscreen;
        });
      }
    } catch (e) {
      // 如果无法安全获取状态，保持当前状态不变
    }
  }

  void _onLongPressStart(LongPressStartDetails details) {
    if (!widget.player.state.playing) {
      return;
    }

    setState(() {
      _isLongPressing = true;
      _originalPlaybackSpeed = widget.player.state.rate;
      widget.player.setRate(2.0);
    });
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    if (!_isLongPressing) {
      return;
    }

    setState(() {
      _isLongPressing = false;
      widget.player.setRate(_originalPlaybackSpeed);
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _playingSubscription?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    if (widget.player.state.playing) {
      _hideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _controlsVisible = false;
          });
        }
      });
    }
  }

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
    setState(() {
      _controlsVisible = true;
    });
    _startHideTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _onBlankAreaTap() {
    // 单击空白区域切换播放/暂停
    if (widget.player.state.playing) {
      widget.player.pause();
      widget.onPause?.call();
    } else {
      widget.player.play();
    }
    setState(() {});
  }

  void _onBlankAreaDoubleTap() {
    // 双击空白区域切换全屏
    _toggleFullscreen();
  }

  void _onSeekStart() {
    if (!mounted) return;
    setState(() {
      _controlsVisible = true;
      _dragPosition = null;
    });
    _hideTimer?.cancel();
    _startHideTimer();
  }

  void _onSeekEnd() {
    setState(() {
      _dragPosition = null;
    });
    _startHideTimer();
  }

  void _onSwipeStart(DragStartDetails details) {
    if (!mounted) return;

    setState(() {
      _isSeekingViaSwipe = true;
      _swipeStartX = details.globalPosition.dx;
      _swipeStartPosition = widget.player.state.position;
      _controlsVisible = true;
    });

    _hideTimer?.cancel();
  }

  void _onSwipeUpdate(DragUpdateDetails details) {
    if (!mounted || !_isSeekingViaSwipe || _screenSize == null) return;

    final screenWidth = _screenSize!.width;
    final swipeDistance = details.globalPosition.dx - _swipeStartX;
    final swipeRatio = swipeDistance / (screenWidth * 0.5);
    final duration = widget.player.state.duration;

    final targetPosition = _swipeStartPosition +
        Duration(
            milliseconds: (duration.inMilliseconds * swipeRatio * 0.1).round());
    final clampedPosition = Duration(
        milliseconds:
            targetPosition.inMilliseconds.clamp(0, duration.inMilliseconds));

    setState(() {
      _dragPosition = clampedPosition;
    });
  }

  void _onSwipeEnd(DragEndDetails details) {
    if (!mounted || !_isSeekingViaSwipe) return;

    if (_dragPosition != null) {
      widget.player.seek(_dragPosition!);
    }

    setState(() {
      _isSeekingViaSwipe = false;
      _dragPosition = null;
    });

    _startHideTimer();
  }

  void _toggleFullscreen() {
    // 直接触发全屏切换，不要提前更新本地状态
    // 状态会在 didUpdateWidget 中同步
    if (_isFullscreen) {
      widget.state.exitFullscreen();
    } else {
      widget.state.enterFullscreen();
    }
  }

  Future<void> _showDLNADialog() async {
    if (widget.player.state.playing) {
      widget.player.pause();
      widget.onPause?.call();
    }

    // 如果在全屏状态，通知父组件并退出全屏
    if (_isFullscreen) {
      widget.onDLNAButtonPressed?.call(true);
      _toggleFullscreen();
    } else {
      // 非全屏状态，直接显示对话框
      await _showDLNADialogInternal();
    }
  }

  Future<void> _showDLNADialogInternal() async {
    // 获取当前播放位置
    final resumePos = widget.player.state.position;

    if (mounted) {
      await showDialog(
        context: context,
        builder: (context) => DLNADeviceDialog(
          currentUrl: widget.videoUrl,
          resumePosition: resumePos,
          videoTitle: widget.videoTitle,
          currentEpisodeIndex: widget.currentEpisodeIndex,
          totalEpisodes: widget.totalEpisodes,
          sourceName: widget.sourceName,
          onCastStarted: widget.onCastStarted,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 如果正在加载视频，只显示加载界面
    if (widget.isLoadingVideo) {
      return Container(
        color: Colors.black.withValues(alpha: 0.7),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
              SizedBox(height: 16),
              Text(
                '视频加载中...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return MouseRegion(
      cursor: (_isFullscreen && !_controlsVisible)
          ? SystemMouseCursors.none
          : SystemMouseCursors.basic,
      onEnter: (_) {
        // 鼠标进入时显示控制栏并启动隐藏定时器
        if (!_controlsVisible) {
          setState(() {
            _controlsVisible = true;
          });
        }
        _startHideTimer();
      },
      onHover: (_) {
        // 鼠标移动时重置隐藏定时器
        if (!_controlsVisible) {
          setState(() {
            _controlsVisible = true;
          });
        }
        _startHideTimer();
      },
      onExit: (_) {
        // 鼠标移出时立即隐藏控制栏
        _hideTimer?.cancel();
        if (_controlsVisible) {
          setState(() {
            _controlsVisible = false;
          });
        }
      },
      child: Stack(
        children: [
          // 背景层 - 处理长按和滑动手势
          Positioned.fill(
            child: GestureDetector(
              onLongPressStart: _onLongPressStart,
              onLongPressEnd: _onLongPressEnd,
              onLongPressCancel: () {
                if (_isLongPressing) {
                  _onLongPressEnd(const LongPressEndDetails());
                }
              },
              onHorizontalDragStart: _onSwipeStart,
              onHorizontalDragUpdate: _onSwipeUpdate,
              onHorizontalDragEnd: _onSwipeEnd,
              onTap: _onBlankAreaTap,
              onDoubleTap: _onBlankAreaDoubleTap,
              behavior: HitTestBehavior.opaque,
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),
          // 长按倍速提示
          if (_isLongPressing)
            Positioned(
              top: 10,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '2x',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.fast_forward,
                    color: Colors.white,
                    size: _isFullscreen ? 32 : 28,
                  ),
                ],
              ),
            ),
          // 顶部返回按钮
          Positioned(
            top: _isFullscreen ? 8 : 4,
            left: _isFullscreen ? 16.0 : 8.0,
            child: AnimatedOpacity(
              opacity: _controlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: HoverButton(
                  onTap: () async {
                    _onUserInteraction();
                    if (_isFullscreen) {
                      _toggleFullscreen();
                    } else {
                      widget.onBackPressed?.call();
                    }
                  },
                  child: Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: _isFullscreen ? 24 : 20,
                  ),
                ),
              ),
            ),
          ),
          // 顶部投屏按钮
          Positioned(
            top: _isFullscreen ? 8 : 4,
            right: _isFullscreen ? 16.0 : 8.0,
            child: AnimatedOpacity(
              opacity: _controlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: HoverButton(
                  onTap: () async {
                    _onUserInteraction();
                    await _showDLNADialog();
                  },
                  child: Icon(
                    Icons.cast,
                    color: Colors.white,
                    size: _isFullscreen ? 24 : 20,
                  ),
                ),
              ),
            ),
          ),
          // 中央播放/暂停按钮 - 暂停时始终显示
          Positioned.fill(
            child: Center(
              child: AnimatedOpacity(
                opacity: (!widget.player.state.playing || _controlsVisible)
                    ? 1.0
                    : 0.0,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: widget.player.state.playing && !_controlsVisible,
                  child: _CenterPlayButton(
                    isPlaying: widget.player.state.playing,
                    isFullscreen: _isFullscreen,
                    onTap: () {
                      _onUserInteraction();
                      if (widget.player.state.playing) {
                        widget.player.pause();
                        widget.onPause?.call();
                      } else {
                        widget.player.play();
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
          // 进度条
          Positioned(
            bottom: _isFullscreen ? 58.0 : 42.0,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              opacity: _controlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: Container(
                  height: 24,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: CustomVideoProgressBar(
                    player: widget.player,
                    onDragStart: _onSeekStart,
                    onDragEnd: _onSeekEnd,
                    onDragUpdate: () {
                      if (!_controlsVisible) {
                        setState(() {
                          _controlsVisible = true;
                        });
                      }
                      _hideTimer?.cancel();
                    },
                    onPositionUpdate: (duration) {
                      setState(() {
                        _dragPosition = duration;
                      });
                    },
                    dragPosition: _dragPosition,
                    isSeekingViaSwipe: _isSeekingViaSwipe,
                  ),
                ),
              ),
            ),
          ),
          // 底部控制栏
          Positioned(
            bottom: _isFullscreen ? 4.0 : -6.0,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              opacity: _controlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: GestureDetector(
                  onTap: () {},
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: _isFullscreen ? 16.0 : 8.0,
                      right: _isFullscreen ? 16.0 : 8.0,
                      top: _isFullscreen ? 0.0 : 0.0,
                      bottom: _isFullscreen ? 8.0 : 8.0,
                    ),
                    child: Row(
                      children: [
                        HoverButton(
                          onTap: () {
                            _onUserInteraction();
                            if (widget.player.state.playing) {
                              widget.player.pause();
                              widget.onPause?.call();
                            } else {
                              widget.player.play();
                            }
                          },
                          child: Icon(
                            widget.player.state.playing
                                ? Icons.pause
                                : Icons.play_arrow,
                            color: Colors.white,
                            size: _isFullscreen ? 28 : 24,
                          ),
                        ),
                        if (!widget.isLastEpisode)
                          Transform.translate(
                            offset: const Offset(-8, 0),
                            child: HoverButton(
                              onTap: () {
                                _onUserInteraction();
                                widget.onNextEpisode?.call();
                              },
                              child: Icon(
                                Icons.skip_next,
                                color: Colors.white,
                                size: _isFullscreen ? 28 : 24,
                              ),
                            ),
                          ),
                        Expanded(
                          child: _buildPositionIndicator(),
                        ),
                        HoverButton(
                          onTap: () async {
                            _onUserInteraction();
                            await _showSpeedDialog();
                          },
                          child: Icon(
                            Icons.speed,
                            color: Colors.white,
                            size: _isFullscreen ? 22 : 20,
                          ),
                        ),
                        HoverButton(
                          onTap: () {
                            _onUserInteraction();
                            _toggleFullscreen();
                          },
                          child: Icon(
                            _isFullscreen
                                ? Icons.fullscreen_exit
                                : Icons.fullscreen,
                            color: Colors.white,
                            size: _isFullscreen ? 28 : 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPositionIndicator() {
    final position = _dragPosition ?? widget.player.state.position;
    final duration = widget.player.state.duration;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Text(
        '${_formatDuration(position)} / ${_formatDuration(duration)}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  Future<void> _showSpeedDialog() async {
    final speeds = [0.5, 0.75, 1.0, 1.5, 2.0];
    final currentSpeed = widget.player.state.rate;

    final chosenSpeed = await showModalBottomSheet<double>(
      context: context,
      builder: (context) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  children: speeds.map((speed) {
                    return ListTile(
                      title: Text(
                        '${speed}x',
                        style: TextStyle(
                          color: speed == currentSpeed
                              ? Theme.of(context).primaryColor
                              : null,
                          fontWeight: speed == currentSpeed
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      onTap: () {
                        Navigator.of(context).pop(speed);
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (chosenSpeed != null) {
      widget.player.setRate(chosenSpeed);
    }
  }
}

class CustomVideoProgressBar extends StatefulWidget {
  final Player player;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;
  final VoidCallback? onDragUpdate;
  final Function(Duration)? onPositionUpdate;
  final Duration? dragPosition;
  final bool isSeekingViaSwipe;

  const CustomVideoProgressBar({
    super.key,
    required this.player,
    this.onDragStart,
    this.onDragEnd,
    this.onDragUpdate,
    this.onPositionUpdate,
    this.dragPosition,
    this.isSeekingViaSwipe = false,
  });

  @override
  State<CustomVideoProgressBar> createState() => _CustomVideoProgressBarState();
}

class _CustomVideoProgressBarState extends State<CustomVideoProgressBar> {
  bool _isDragging = false;
  double _dragValue = 0.0;
  bool _isHoveringThumb = false;
  StreamSubscription? _positionSubscription;

  @override
  void initState() {
    super.initState();
    _positionSubscription = widget.player.stream.position.listen((_) {
      if (mounted && !_isDragging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final duration = widget.player.state.duration;
    final position = widget.dragPosition ?? widget.player.state.position;

    double value = 0.0;
    if (duration.inMilliseconds > 0) {
      value = position.inMilliseconds / duration.inMilliseconds;
    }

    if (_isDragging) {
      value = _dragValue;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (details) {
          _isDragging = true;
          widget.onDragStart?.call();
          _updateDragPosition(details.localPosition.dx, context);
        },
        onHorizontalDragUpdate: (details) {
          if (_isDragging) {
            widget.onDragUpdate?.call();
            _updateDragPosition(details.localPosition.dx, context);
          }
        },
        onHorizontalDragEnd: (details) {
          if (_isDragging) {
            final seekPosition = Duration(
                milliseconds: (_dragValue * duration.inMilliseconds).round());
            widget.player.seek(seekPosition);

            setState(() {
              _isDragging = false;
            });
            widget.onDragEnd?.call();
          }
        },
        onTapDown: (details) {
          widget.onDragStart?.call();
          _updateDragPosition(details.localPosition.dx, context);
          final seekPosition = Duration(
              milliseconds: (_dragValue * duration.inMilliseconds).round());
          widget.player.seek(seekPosition);
          widget.onDragEnd?.call();
        },
        child: Container(
          height: 24,
          color: Colors.transparent,
          child: Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final progressWidth = constraints.maxWidth;
                final progressValue = value.clamp(0.0, 1.0);
                final thumbPosition = (progressValue * progressWidth)
                    .clamp(8.0, progressWidth - 8.0);

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // 进度条背景
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 9,
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                    // 已播放进度
                    Positioned(
                      left: 0,
                      top: 9,
                      child: Container(
                        width: progressValue * progressWidth,
                        height: 6,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: Colors.red,
                        ),
                      ),
                    ),
                    // 可拖拽的圆形把手
                    Positioned(
                      left: thumbPosition - 8,
                      top: 4,
                      child: MouseRegion(
                        onEnter: (_) => setState(() => _isHoveringThumb = true),
                        onExit: (_) => setState(() => _isHoveringThumb = false),
                        child: AnimatedScale(
                          scale: (_isHoveringThumb ||
                                  _isDragging ||
                                  widget.isSeekingViaSwipe)
                              ? 1.25
                              : 1.0,
                          duration: const Duration(milliseconds: 150),
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.red,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _updateDragPosition(double dx, BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final width = box.size.width;
    final value = (dx / width).clamp(0.0, 1.0);

    setState(() {
      _dragValue = value;
    });

    final duration = widget.player.state.duration;
    final position =
        Duration(milliseconds: (value * duration.inMilliseconds).round());

    widget.onPositionUpdate?.call(position);
  }
}

// 中央播放/暂停按钮组件 - 支持 hover 效果
class _CenterPlayButton extends StatefulWidget {
  final bool isPlaying;
  final bool isFullscreen;
  final VoidCallback onTap;

  const _CenterPlayButton({
    required this.isPlaying,
    required this.isFullscreen,
    required this.onTap,
  });

  @override
  State<_CenterPlayButton> createState() => _CenterPlayButtonState();
}

class _CenterPlayButtonState extends State<_CenterPlayButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    // 暂停时始终显示背景，播放时仅 hover 时显示背景
    final showBackground = !widget.isPlaying || _isHovering;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 背景圆形 - 使用 AnimatedOpacity 实现淡入淡出
            AnimatedOpacity(
              opacity: showBackground ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.withValues(alpha: 0.7),
                ),
                child: SizedBox(
                  width: widget.isFullscreen ? 64 : 48,
                  height: widget.isFullscreen ? 64 : 48,
                ),
              ),
            ),
            // 图标
            Padding(
              padding: const EdgeInsets.all(16),
              child: Icon(
                widget.isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: widget.isFullscreen ? 64 : 48,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
