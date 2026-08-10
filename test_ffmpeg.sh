#!/bin/bash
scaledFrameW=459
scaledFrameH=918
scaledHoleW=400
scaledHoleH=800
canvasW=1920
canvasH=1080
colorHex="FFFFFF"
visibleW=459
visibleH=918
cropOffsetX=0
cropOffsetY=0
absVidX=0
absVidY=0
scaledHoleX=20
scaledHoleY=50

/opt/homebrew/bin/ffmpeg -f lavfi -i testsrc=d=1 -f lavfi -i testsrc=d=1 -f lavfi -i testsrc=d=1 \
-f lavfi -i color=c=#$colorHex:s=${canvasW}x${canvasH}:r=60 \
-filter_complex \
"[0:v]scale=$scaledHoleW:$scaledHoleH:force_original_aspect_ratio=increase,crop=$scaledHoleW:$scaledHoleH,format=rgba[vid_scaled];\
[2:v]scale=$scaledHoleW:$scaledHoleH,format=rgba[mask];\
[vid_scaled][mask]alphamerge[vid_rounded];\
[1:v]scale=$scaledFrameW:$scaledFrameH[frame];\
color=c=black@0:s=${scaledFrameW}x${scaledFrameH}:r=60,format=rgba[transparent_bg];\
[transparent_bg][vid_rounded]overlay=$scaledHoleX:$scaledHoleY:shortest=1[device_with_vid];\
[device_with_vid][frame]overlay=0:0[full_device];\
[full_device]crop=$visibleW:$visibleH:$cropOffsetX:$cropOffsetY[cropped_device];\
[3:v][cropped_device]overlay=(main_w-overlay_w)/2:(main_h-overlay_h)/2[out]" \
-map '[out]' -y test_out.mp4
