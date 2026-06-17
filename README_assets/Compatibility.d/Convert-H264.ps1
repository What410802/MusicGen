param($i, $o)
ffmpeg -i $i -c:v libx264 -c:a copy -movflags +faststart $o