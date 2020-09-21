#!/bin/bash

#
# itmpcsync
# Usage: itmpcsync <iTunes XML Library Path>
#

# Dependencies:
# mpc

# The way this will work is:
# 0.) Read the iTunes XML library - get play counts for each song.
# 1.) Checks if we have sync data from last time script was run.
# 2.) If there was data last time, we find the difference in play counts.
# 3.) Add the difference in play counts with the current MPD play counts.
# 4.) Set MPD play counts to the above.

# To find song by name in iTunes we use this, for example:
# mpc search '((artist == "Fleetwood Mac") AND (title == "Dreams"))'

# To get song play count we do:
# mpc sticker "$songname" get playcount
# And to set:
# mpc sticker "$songname" set playcount $newplaycount

# Path of iTunes XML library
ITUNES_LIB_PATH="$@"

# Check if we passed anything.
if [[ -z "$ITUNES_LIB_PATH" ]]; then
	echo "Usage: itmpcsync <iTunes XML Library Path>"
	exit -1
fi

# Make sure file exists
if [[ ! -f "$ITUNES_LIB_PATH" ]]; then
	echo "Library file at '$ITUNES_LIB_PATH' does not exist."
	exit -1
fi

# First check if MPD is actually running.
if ! mpc status -q; then
	echo "MPC returned error when checking for status. Assuming MPD is not running - cannot sync."
	notify-send "itmpcsync" "MPD not running. Not syncing." --expire-time=3000
	exit -1
fi

# Convert the library into a format we can read.
./bin/itxmlconvert "$ITUNES_LIB_PATH" > lib_cur.data || exit -1

# Make sure we don't append to an old lib_now.
rm -f .lib_now.data

# If there was a previous sync, do a diff to only get stuff that actually changed.
if [[ -f "lib_prev.data" ]]; then
	# Get lines of stuff that changed.
	diff -U0 lib_prev.data lib_cur.data > .diff.data

	# Create the next
	echo "Syncing..."
	touch .lib_now.data

	# Iterate over the diff data.
	# There are 3 lines we need to look for usually:
	# * A line beginning with "@@", this indicates a new change section.
	# * A line beginning with a "+", this has the current state.
	# * (Optionally) A line beginning with a "-", this is the old state.
	#   Note that the "-", line will not exist for newly added songs.
	i=0
	old=""
	cur=""
	while read ln; do
		# Check if it is beginning of section.
		if [[ $ln  =~ ^\@\@.* ]]; then
			# Skip if it's the first header.
			if [[ $i -eq 0 ]]; then
				i=$(($i+1))
				continue
			fi

			# Get the play counts.
			oldcount=0
			if [[ -n "$old" ]]; then
				# Only get this if we actually have the string.
				oldcount=$(echo "$old" | awk -F "|" '{print $4;}')
				oldcount=$(($oldcount+0))
			fi
			curcount=$(echo "$cur" | awk -F "|" '{print $4;}')
			newcount=$((($curcount)-($oldcount)))
			new="$(echo "$cur" | awk -F "|" '{print $1;}')|$(echo "$cur" | awk -F "|" '{print $2;}')|$(echo "$cur" | awk -F "|" '{print $3;}')|$newcount"
			new=${new#"+"}
			echo "$new" >> .lib_now.data

			# Increment counter for next loop.
			i=$(($i+1))
			old=""
			cur=""

		# Check if old state.
		elif [[ $ln =~ ^\-.* ]]; then
			old=$ln

		# Check if current state.
		elif [[ $ln =~ ^\+.* ]]; then
			cur=$ln
		fi

	done <.diff.data

	# Make sure we handle the final section in diff.
	if [[ -n "$cur" ]]; then
			# Get the play counts.
			oldcount=0
			if [[ -n "$old" ]]; then
				# Only get this if we actually have the string.
				oldcount=$(echo "$old" | awk -F "|" '{print $4;}')
			fi
			curcount=$(echo "$cur" | awk -F "|" '{print $4;}')
			newcount=$((($curcount)-($oldcount)))
			new="$(echo "$cur" | awk -F "|" '{print $1;}')|$(echo "$cur" | awk -F "|" '{print $2;}')|$(echo "$cur" | awk -F "|" '{print $3;}')|$newcount"
			new=${new#"+"}
			echo "$new" >> .lib_now.data
	fi
else
	# Work with all the data.
	echo "Syncing for first time - this can take a while depending on how much music you have..."
	cp lib_cur.data .lib_now.data
fi

# Number of songs updated
songsupdated=0

# Number of songs skipped
songsskipped=0

# Iterate over all the lines in our data.
while read ln; do
	# Get the information on this line.
	title=$(echo "$ln" | awk -F "|" '{print $1;}' | sed 's/\"/\\\"/g')
	artist=$(echo "$ln" | awk -F "|" '{print $3;}' | sed 's/\"/\\\"/g')

	# Check if MPD has the song.
	filename=$(mpc search "((artist == \"$artist\") AND (title == \"$title\"))")

	# Check if we got any duplicates. If so, we need to bring in the album too.
	songcount=$(echo "$filename" | wc -l)
	if [[ $songcount -eq 0 ]]; then
		# Skip if not in library.
		echo "$title not found in MPD library."
		continue
	elif [[ $songcount -gt 1 ]]; then
		# Use the album title to find the exact song.
		album=$(echo "$ln" | awk -F "|" '{print $2;}' | sed 's/\"/\\\"/g')

		# Check if MPD has the song.
		filename=$(mpc search "((artist == \"$artist\") AND (album == \"$album\") AND (title == \"$title\"))")
		songcount=$(echo "$filename" | wc -l)
		if [[ $songcount -eq 0 ]]; then
			# Give up trying to find it.
			echo "$title not found in MPD library."
			continue
		fi
	fi

	# Make sure we actually have a song to work with.
	if [[ -z $filename ]]; then
		echo "Skipping '$title' by '$artist' - not in MPD library."

		# Remove from the library file, so all play counts would be added if it were
		# to get added to the MPD library.
		# We need to escape title, artist, and album to delete them. This
		# is probably not the safest thing to do...
		d_title=$(echo "$ln" | awk -F "|" '{print $1;}' | sed -e 's/[]\/$*.^[]/\\&/g')
		d_album=$(echo "$ln" | awk -F "|" '{print $2;}' | sed -e 's/[]\/$*.^[]/\\&/g')
		d_artist=$(echo "$ln" | awk -F "|" '{print $3;}' | sed -e 's/[]\/$*.^[]/\\&/g')

		sed -i "/$d_title|$d_album|$d_artist|/d" lib_cur.data

		songsskipped=$(($songsskipped+1))
		continue
	fi

	# Check if there is already a play count.
	plays_mpd=0
	stickers=$(mpc sticker "$filename" list | grep -E ^playcount\=.*)
	if [[ -n "$stickers" ]]; then
		# Get actual playcount.
		plays_mpd=${stickers#"playcount="}
		plays_mpd=$((plays_mpd+0))
	fi

	# Add the MPD playcount and iTunes playcounts.
	plays_it=$(echo "$ln" | awk -F "|" '{print $4;}')
	plays_total=$(($plays_mpd + $plays_it))

	# Finally, set the final playcount!
	if [[ $plays_total -gt 0 ]]; then
		mpc sticker "$filename" set playcount $plays_total
	fi

	# Increment songs updated.
	songsupdated=$(($songsupdated+1))
done <.lib_now.data

echo "$songsupdated synced, $songsskipped skipped."

#if [[ $songsupdated -gt 0 ]]; then
	notify-send "itmpcsync" "$songsupdated synced. ($songsskipped skipped)" --expire-time=3000
#fi

# Remove old previous lib and replace with our current one.
mv lib_cur.data lib_prev.data

# Remove lib_now since we're done with it.
rm -f .lib_now.data
rm -f .diff.data
