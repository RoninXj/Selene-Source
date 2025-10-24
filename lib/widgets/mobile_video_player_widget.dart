import 'package:flutter/material.dart';
import 'ffmpeg_video_player_widget.dart';
import 'video_player_surface.dart';

typedef MobileVideoPlayerWidgetController = FFmpegVideoPlayerWidgetController;

class MobileVideoPlayerWidget extends StatelessWidget {
  final String? url;
  final Map<String, String>? headers;
  final VoidCallback? onBackPressed;
  final Function(MobileVideoPlayerWidgetController)? onControllerCreated;
  final VoidCallback? onReady;
  final VoidCallback? onNextEpisode;
  final VoidCallback? onVideoCompleted;
  final VoidCallback? onPause;
  final bool isLastEpisode;
  final Function(dynamic)? onCastStarted;
  final String? videoTitle;
  final int? currentEpisodeIndex;
  final int? totalEpisodes;
  final String? sourceName;
  final bool live;

  const MobileVideoPlayerWidget({
    super.key,
    this.url,
    this.headers,
    this.onBackPressed,
    this.onControllerCreated,
    this.onReady,
    this.onNextEpisode,
    this.onVideoCompleted,
    this.onPause,
    this.isLastEpisode = false,
    this.onCastStarted,
    this.videoTitle,
    this.currentEpisodeIndex,
    this.totalEpisodes,
    this.sourceName,
    this.live = false,
  });

  @override
  Widget build(BuildContext context) {
    return FFmpegVideoPlayerWidget(
      surface: VideoPlayerSurface.mobile,
      url: url,
      headers: headers,
      onBackPressed: onBackPressed,
      onControllerCreated: onControllerCreated,
      onReady: onReady,
      onNextEpisode: onNextEpisode,
      onVideoCompleted: onVideoCompleted,
      onPause: onPause,
      isLastEpisode: isLastEpisode,
      onCastStarted: onCastStarted,
      videoTitle: videoTitle,
      currentEpisodeIndex: currentEpisodeIndex,
      totalEpisodes: totalEpisodes,
      sourceName: sourceName,
      live: live,
    );
  }
}
