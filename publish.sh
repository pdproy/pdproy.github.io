#!/bin/bash

set -e

CSS_URL="https://cdn.jsdelivr.net/gh/pages-themes/minimal@latest/assets/css/style.css"
SRC_DIR="src"
OUTPUT_DIR="output"
DOCS_DIR="docs"


info() {
    echo "== $*"
}

update_links() {
    sed -i -e "s|\(link rel=\"stylesheet\" href=\)\".*\"|\1\"${CSS_URL}\"|" $1/*.html
    sed -i -e 's|\(<a href=.*\)\.adoc"|\1.html"|' $1/*.html

    sed -i -e "s|\(link rel=\"stylesheet\" href=\)\".*\"|\1\"${CSS_URL}\"|" $1/*/*.html
    sed -i -e 's|\(<a href=.*\)\.adoc"|\1.html"|' $1/*/*.html
}

git_checkout() {
    git checkout -q "$1"
}

main() {
    git_checkout "dev"

    info "Converting AsciiDoc files to HTML..."
    mkdir -p ${OUTPUT_DIR}
    docker run   -u $(id -u):$(id -g) --rm -v .:/documents \
        asciidoctor/docker-asciidoctor \
        asciidoctor ${SRC_DIR}/*.adoc ${SRC_DIR}/*/*.adoc

    rsync -a ${SRC_DIR}/ ${OUTPUT_DIR}/
    find ${OUTPUT_DIR} -type f ! -name '*.html' -delete

    info "Switching to gh-pages branch"
    git_checkout "gh-pages"

    update_links ${OUTPUT_DIR}

    info "Updating docs directory"
    rm -rf $DOCS_DIR/*
    mkdir -p ${DOCS_DIR}
    cp -r ${OUTPUT_DIR}/* ${DOCS_DIR}/

    info "Committing and pushing changes"
    git add ${DOCS_DIR}
    git commit -q -m "Update published site"
    git push origin gh-pages

    info "Switching back to dev branch"
    git_checkout "dev"
}

main
