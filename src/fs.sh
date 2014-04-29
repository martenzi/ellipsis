#!/usr/bin/env bash
#
# fs.sh
# Files/path functions used by ellipis.

# Initialize ourselves if we haven't yet.
if [[ $ELLIPSIS_INIT -ne 1 ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")"/init.sh
fi

# return true if folder is empty
fs.folder_empty() {
    if [ "$(find $1 -prune -empty)" ]; then
        return 0
    fi
    return 1
}

# check whether file exists
fs.file_exists() {
    if [[ -e "$1" ]]; then
        return 0
    fi
    return 1
}

# check whether file is a symlink
fs.is_symlink() {
    if [[ -L "$1" ]]; then
        return 0
    fi
    return 1
}

# Check whether symlink is broken
fs.is_broken_symlink() {
    if [[ -L "$1" && ! -e "$1" ]]; then
        return 0
    fi
    return 1
}

# List symlinks in a folder, defaulting to ELLIPSIS_HOME.
fs.list_symlinks() {
    find "${1:-$ELLIPSIS_HOME}" -maxdepth 1 -type l
}

# List all symlinks (slightly optimized over calling pkg.list_symlinks for each
# package.
# List all symlinks and files they resolve to
fs.list_symlink_mappings() {
    for file in $(fs.list_symlinks); do
        local link="$(readlink $file)"
        if [[ "$link" == $ELLIPSIS_PATH* ]]; then
            echo "$(utils.strip_packages_dir $link) -> $(path.relative_path $file)";
        fi
    done
}

# backup existing file, ensuring you don't overwrite existing backups
fs.backup() {
    local original="$1"
    local backup="$original.bak"
    local name="${original##*/}"

    # remove broken symlink
    if fs.is_broken_symlink "$original"; then
        echo "rm ~/$name (broken link to $(readlink $original))"
        rm $original
        return
    fi

    # no file exists, simply ignore
    if ! fs.file_exists "$original"; then
        return
    fi

    # backup file
    if fs.file_exists "$backup"; then
        n=1
        while fs.file_exists "$backup.$n"; do
            n=$((n+1))
        done
        backup="$backup.$n"
    fi

    echo "mv ~/$name $backup"
    mv "$original" "$backup"
}

# symlink a single file into ELLIPSIS_HOME
fs.link_file() {
    local src="$1"
    local name="${src##*/}"
    local dest="${2:-$ELLIPSIS_HOME}/.$name"

    fs.backup "$dest"

    echo linking "$dest"
    ln -s "$src" "$dest"
}

# find all files in dir excluding the dir itself, hidden files, README,
# LICENSE, *.rst, *.md, and *.txt and symlink into ELLIPSIS_HOME.
fs.link_files() {
    for file in $(find "$1" -maxdepth 1 -name '*' \
                                      ! -name '.*' \
                                      ! -name 'README' \
                                      ! -name 'LICENSE' \
                                      ! -name '*.md' \
                                      ! -name '*.rst' \
                                      ! -name '*.txt' \
                                      ! -wholename "$1" \
                                      ! -name "ellipsis.sh" | sort); do
        fs.link_file "$file"
    done
}
