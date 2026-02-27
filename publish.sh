#!/bin/bash

set -e

# BACKEND decided whether AsciiDoctor that is installed locally will be used
# or one from the container.
BACKEND="local"

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

generate_html_local() {
    asciidoctor ${SRC_DIR}/*.adoc ${SRC_DIR}/*/*.adoc
}

generate_html_docker() {
    docker run -u $(id -u):$(id -g) --rm -v .:/documents \
        asciidoctor/docker-asciidoctor \
        asciidoctor ${SRC_DIR}/*.adoc ${SRC_DIR}/*/*.adoc
}

generate_html() {
    if [[ "${BACKEND}" = "docker" ]]; then
        generate_html_docker
    else
        generate_html_local
    fi
}

usage() {
    cat <<EOF
Usage: ${0##*/} [OPTIONS]
Convert AsciiDoc to HTML and publish site.

Options:
  -b, --backend[=MODE]    User BACKEND for conversion. Possible values: local (default), docker
  -h, --help              Display this help and exit
EOF
}

main() {
    git_checkout "dev"

    info "Converting AsciiDoc files to HTML..."
    mkdir -p ${OUTPUT_DIR}
    generate_html

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

while (($#)); do
    case $1 in
    -b=* | --backend=*)
        BACKEND="${1#*=}"
        ;;
    -h | --help)
        usage
        exit 0
        ;;
    -*)
        die "Unknown option $1"
        ;;
    *)
        break
        ;;
    esac
    shift
done

main
