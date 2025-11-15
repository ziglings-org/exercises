#!/bin/sh
#
#    "How do you pick up the threads of an old life?
#     How do you go on, when in your heart you begin
#       to understand... there is no going back?
#      There are some things that time cannot mend.
#    Some hurts that go too deep, that have taken hold."
#             Frodo, The Return of the King
#
#
# This script shall repair the patches for the little
# broken programs using the old patches in this directory
# first, to heal them and then create new and better
# patches, with Gollum's help.
#
set -e

# We check ourselves before we wreck ourselves.
if [ ! -f patches/frodo.sh ]
then
    echo "But I must be run from the project root directory."
    exit 1
fi

# Create directory of answers if it doesn't already exist.
mkdir -p answers

# Cycle through all the little broken Zig applications.
i=0
for broken in exercises/*.zig
do
	((i=i+1))

    # Remove the dir and extension, rendering the True Name.
    true_name=$(basename "$broken" .zig)
    patch_name="patches/patches/$true_name.patch"
    healed_name="answers/$true_name.zig"
    cp "$broken" "$healed_name"
	# echo "$patch_name"

    if [ -f "$patch_name" ]
    then
        # Apply the bandages to the wounds, grow new limbs, let
        # new life spring into the broken bodies of the fallen.
        echo Healing "$true_name"...
		patch -i "$patch_name" "$healed_name"

		# Create new prescriptions...
		echo Repairing "$patch_name"...
		if [ "$true_name.patch" = "999_the_end.patch" ]
		then
			i=999
		fi
		# with gollum's help!
		./patches/gollum.sh $i
    else
        echo Cannot repair "$true_name". No patch found.
    fi
done

