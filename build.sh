#!/bin/bash

SEPERATOR='__BUILD_DELIM__'
OUTPUT_PATH='output'
PAGES_PATH=$OUTPUT_PATH'/pages'
COMRAK_THEME="Solarized (light)"


parse_index () {
    for f in "$1"/*.md
    do
        creation_date_epoch=$(git log --pretty="format:%at" --grep='new post:' "$f" 2> /dev/null | tail -1)
        title=$(git log --pretty="format:%s" --grep='new post:' "$f" 2> /dev/null | tail -1 | cut -d ' ' -f 3-) 
        printf '%d\t%s\t%s\n' "$creation_date_epoch" "$f" "$title"
    done
}

create_index() {
    output_path=$OUTPUT_PATH/index.html

    cat include/header.html >| $output_path
    cat include/index.html >> $output_path

    while IFS=$'\t' read -r creation_date_epoch f title; do
        filename=$(echo `basename ${f%%.*}`)
        creation_date=$(date -d @$creation_date_epoch '+%m-%d-%Y') 

        echo $creation_date >> $output_path
        echo "<a href=\"pages/$filename\">" >> $output_path
        echo $title >> $output_path
        echo "</a><br/>" >> $output_path
    done < /dev/stdin

    cat include/footer.html >> $output_path
}

create_posts() {
    mkdir -p $PAGES_PATH
    for f in "$1"/*.md
    do
        input_path_without_extension=${f%%.*}/
        output_path=$(echo $PAGES_PATH/`basename ${f%%.*}`)

        mkdir -p $output_path
        cp -r $input_path_without_extension/* $output_path 2> /dev/null

        cat include/header.html >| $output_path/index.html
        comrak $f --syntax-highlighting "$COMRAK_THEME" --gfm >> $output_path/index.html
        cat include/footer.html >> $output_path/index.html
    done  
}

create_posts posts
parse_index posts | sort -rt $'\t' | create_index