
"""
Convert a human-readable note sequence (with octave support)
into the contents of music_list_rom.coe and music_rom.coe.

Header syntax:
  ==[<begin>] <begin> <end> <denom>:<bpm>
  "==" may be immediately followed by the first number (e.g. ==16)
  or separated by a space (e.g. == 16). <begin> and <end> can be '?' or an integer.

Note syntax:
  <denom>[.] <pitch>[<octave>]
  pitch: A-G, optionally '#', or '-' for rest.
  octave: optional single digit (default = 4).
"""

import sys, pathlib
import re
from typing import List, Tuple, Dict, Optional

# ----------------------------------------------------------------------
# Constants (must match the Verilog design)
# ----------------------------------------------------------------------
CLK_FREQ = 50_000_000          # 50 MHz
NOTE_LENGTH_FRACTIONAL_BITS = 15
FULL_NOTE_LENGTH = 1 << NOTE_LENGTH_FRACTIONAL_BITS   # 32768
REST_NOTE_LENGTH = FULL_NOTE_LENGTH   # full note pause used for padding
DEFAULT_OCTAVE = 4

# Mapping from note name to inoctave (4-bit value)
PITCH_TO_INOCTAVE = {
	'C':  0b0010,
	'C#': 0b0011,
	'D':  0b0100,
	'D#': 0b0101,
	'E':  0b0110,
	'F':  0b1000,
	'F#': 0b1001,
	'G':  0b1010,
	'G#': 0b1011,
	'A':  0b1100,
	'A#': 0b1101,
	'B':  0b1110,
}
REST_INOCTAVE = 0b0000
REST_OCTAVE   = 0b0000

# ----------------------------------------------------------------------
# Helper functions
# ----------------------------------------------------------------------
def compute_abs_fullnote_length(beat_denom: int, bpm: int) -> int:
	"""abs_fullnote_length = CLK_FREQ * 60 * beat_denom / bpm (integer)"""
	return (CLK_FREQ * 60 * beat_denom) // bpm

def note_fraction_to_length(num: int, den: int, dotted: bool) -> int:
	if dotted:
		num *= 3
		den *= 2
	return (num * FULL_NOTE_LENGTH) // den

def format_music_rom_entry(note_length: int, octave: int, inoctave: int) -> str:
	"""Return 24-bit binary string: 16 bits note_length, 4 bits octave, 4 bits inoctave."""
	return f"{note_length:016b}{octave:04b}{inoctave:04b}"

def format_music_list_entry(begin: int, end: int, abs_full: int) -> str:
	"""Return 64-bit binary string: 16 bits begin, 16 bits end, 32 bits abs_fullnote_length."""
	return f"{begin:016b}{end:016b}{abs_full:032b}"

# ----------------------------------------------------------------------
# Parser
# ----------------------------------------------------------------------
def parse_songs(songs_str: str) -> Tuple[List[str], List[str]]:
	"""
	Parse the human-readable song file.
	Returns:
		music_list_rom_entries: list of 64-bit binary strings for the list ROM.
		music_rom_entries: list of 24-bit binary strings for the music ROM.
	"""
	lines = songs_str.strip().splitlines()
	songs = []                     # each song: dict with header info + list of notes
	current_song_notes = None
	current_header = None

	# Regex for a note line: <denom>[.] <pitch>[<octave>]
	note_re = re.compile(r'^(\d+)(?:/(\d+))?(\.?)\s*([A-G](?:#)?|-)\s*(\d)?\s*$') # In this line, (?:#)? has the same function as #?, but the former is more suitable for extend to both # and b: ([A-G](?:#|b)?).
	# Regex for header line: ==[<begin>] <begin> <end> <denom>:<bpm>
	header_re = re.compile(r'^==\s*(\?|\d+)\s+(\?|\d+)\s+(\d+)\s*:\s*(\d+)\s*$')

	for raw_line in lines:
		# --- comment stripping ---
		# Remove everything from "//" to end of line, then strip whitespace.
		comment_pos = raw_line.find("//")
		if comment_pos != -1:
			raw_line = raw_line[:comment_pos]
		line = raw_line.strip()
		if not line:
			continue

		# Header line
		if line.startswith("=="):
			# finalize previous song if any
			if current_header is not None:
				songs.append({
					'header': current_header,
					'notes': current_song_notes
				})
			m = header_re.match(line)
			if not m:
				raise ValueError(f"Invalid header line: {line}")
			begin_str = m.group(1)
			end_str   = m.group(2)
			beat_denom = int(m.group(3))
			bpm = int(m.group(4))
			abs_full = compute_abs_fullnote_length(beat_denom, bpm)
			current_header = {
				'begin_str': begin_str,
				'end_str': end_str,
				'abs_fullnote_length': abs_full
			}
			current_song_notes = []   # will hold (note_length, octave, inoctave)

			# # DEBUG
			# print("### begin_str: ", begin_str)
			# print("### end_str: ", end_str)
			# print("### beat_denom: ", beat_denom)
			# print("### bpm: ", bpm)
			
		else:
			# Note line
			m = note_re.match(line)
			if not m:
				raise ValueError(f"Invalid note line: {line}")
			d1 = int(m.group(1))
			d2str = m.group(2)
			dotted = (m.group(3) == '.')
			pitch = m.group(4)
			octave_str = m.group(5)

			if d2str:
				numerator = d1
				denominator = int(d2str)
			else:
				numerator = 1
				denominator = d1
			note_length = note_fraction_to_length(numerator, denominator, dotted)

			if pitch == '-':
				octave = REST_OCTAVE
				inoctave = REST_INOCTAVE
			else:
				inoctave = PITCH_TO_INOCTAVE[pitch]
				octave = int(octave_str) if octave_str is not None else DEFAULT_OCTAVE

			current_song_notes.append((note_length, octave, inoctave))
			
			# # DEBUG
			# print("## denom: ", denom)
			# print("## dotted: ", dotted)
			# print("## pitch: ", pitch)
			# print("## octave_str: ", octave_str)

	# Last song
	if current_header is not None:
		songs.append({
			'header': current_header,
			'notes': current_song_notes
		})

	# ------------------------------------------------------------------
	# Assign ROM addresses and build ROM contents
	# ------------------------------------------------------------------
	music_rom_dict: Dict[int, Tuple[int, int, int]] = {}  # addr -> (len, oct, ino)
	music_list_entries = []
	prev_end_addr = 0

	for i, song in enumerate(songs):
		hdr = song['header']
		notes = song['notes']

		# Determine begin address
		begin_str = hdr['begin_str']
		if begin_str == '?':
			if i == 0:
				begin_addr = 0
			else:
				begin_addr = prev_end_addr
		else:
			begin_addr = int(begin_str)

		# # Fill any gap before begin_addr with rests
		# for a in range(prev_end_addr, begin_addr):
		# 	if a not in music_rom_dict:
		# 		music_rom_dict[a] = (REST_NOTE_LENGTH, REST_OCTAVE, REST_INOCTAVE)

		# Write notes
		addr = begin_addr
		for nlen, noct, nino in notes:
			music_rom_dict[addr] = (nlen, noct, nino)
			addr += 1
		current_end_hint = addr

		# Determine end address
		end_str = hdr['end_str']
		if end_str == '?':
			end_addr = current_end_hint
		else:
			end_addr = int(end_str)
			if end_addr < current_end_hint:
				raise ValueError(
					f"Song {i+1}: specified end address {end_addr} is smaller than required {current_end_hint}."
				)
			# # Pad between last note and end_addr with rests
			# for a in range(current_end_hint, end_addr):
			# 	music_rom_dict[a] = (REST_NOTE_LENGTH, REST_OCTAVE, REST_INOCTAVE)

		# Store list entry
		music_list_entries.append(
			format_music_list_entry(begin_addr, end_addr, hdr['abs_fullnote_length'])
		)
		prev_end_addr = end_addr

	# Build final music_rom array up to the highest used address
	max_addr = prev_end_addr
	if music_rom_dict:
		max_addr = max(max_addr, max(music_rom_dict.keys()) + 1)

	music_rom_entries = []
	for a in range(max_addr):
		if a in music_rom_dict:
			nlen, noct, nino = music_rom_dict[a]
		else:
			nlen, noct, nino = REST_NOTE_LENGTH, REST_OCTAVE, REST_INOCTAVE
		music_rom_entries.append(format_music_rom_entry(nlen, noct, nino))

	music_rom_entries.append(format_music_rom_entry(REST_NOTE_LENGTH, REST_OCTAVE, REST_INOCTAVE)) # buffer, avoiding reading in a 0-length note after the last note in the ROM.

	return music_list_entries, music_rom_entries

# ----------------------------------------------------------------------
# COE file generation
# ----------------------------------------------------------------------
def generate_coe(list_entries, rom_entries) -> Tuple[str, str]:
	"""Create the full .coe file contents as strings."""
	list_coe = (
		"; 16b: begin, 16b: end, 32b: abs_fullnote_length\n"+"\n"*5+
		";      ::      ><      ::      ><      ::      ::      ::      >\n"
		"MEMORY_INITIALIZATION_RADIX=2;\n"
		"MEMORY_INITIALIZATION_VECTOR=\n"
	)
	for i, entry in enumerate(list_entries):
		if i == len(list_entries) - 1:
			list_coe += f"{entry};\n"
		else:
			list_coe += f"{entry},\n"

	rom_coe = (
		"; 16b(0)+4b(1)+4b(2): 0: length, 1: which octave, 2: which note (12 in total)\n"+"\n"*5+
		";  ::  ::  ::  ><  ><  >\n"
		"MEMORY_INITIALIZATION_RADIX=2;\n"
		"MEMORY_INITIALIZATION_VECTOR=\n"
	)
	for i, entry in enumerate(rom_entries):
		if i == len(rom_entries) - 1:
			rom_coe += f"{entry};\n"
		else:
			rom_coe += f"{entry},\n"

	return list_coe, rom_coe

# ----------------------------------------------------------------------
# Example & main
# ----------------------------------------------------------------------
def main():
	# Example input using the new octave notation (and the original header style)
	# Note: This does not support random-order address assignment, which will be way too much complex. So you should write songs in order.
	HERE = pathlib.Path(__file__).parent
	try:
		in_file = HERE/"in"/"in.txt"
		# print(in_file.absolute()) # Relative path causes bug! In Python, relative path is relative to CWD by default.
		songs_input = in_file.read_text(encoding='utf-8')
	except Exception as e:
		print(f"Error reading input file: {e}", file=sys.stderr)
		sys.exit(1)

	try:
		list_entries, rom_entries = parse_songs(songs_input)
	except Exception as e:
		print(f"Error parsing input: {e}", file=sys.stderr)
		sys.exit(2)

	list_coe, rom_coe = generate_coe(list_entries, rom_entries)


	out_dir = HERE/"out"
	out_dir.mkdir(parents=True, exist_ok=True)
	music_list_rom_file = out_dir/'music_list_rom.coe'
	music_rom_file = out_dir/'music_rom.coe'
	music_list_rom_file.write_text(list_coe, encoding='utf-8')
	music_rom_file.write_text(rom_coe, encoding='utf-8')

	# with open("out/music_list_rom.coe", "w", encoding="utf-8") as f:
	# 	f.write(list_coe)
	# with open("out/music_rom.coe", "w", encoding="utf-8") as f:
	# 	f.write(rom_coe)

	# print("=== music_list_rom.coe ===")
	# print(list_coe)
	# print("=== music_rom.coe ===")
	# print(rom_coe)

if __name__ == "__main__":
	main()