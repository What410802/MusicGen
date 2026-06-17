param($i)
ffprobe -v error -show_entries stream=codec_name,codec_type,profile,sample_rate,channels,bits_per_sample -of default=noprint_wrappers=1 $i
