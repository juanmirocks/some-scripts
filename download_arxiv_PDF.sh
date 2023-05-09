#!/bin/bash

download_arxiv_PDF() {
  article="$1"
  save_to="${2-$PWD}"

  # Check if input is a URL or an identifier
  if [[ "$article" =~ ^https?://arxiv.org/abs/(.+)$ ]]; then
    identifier="${BASH_REMATCH[1]}"
  elif [[ -z "$article" ]]; then
    >&2 echo "Error: Empty arXiv URL or identifier"
    exit 1
  else
      identifier="$article"
  fi

  # Get the metadata for the article
  metadata=$(curl -sLH "Accept: application/json" "http://export.arxiv.org/api/query?id_list=$identifier")

  # Check if the API returned an error
  if [[ $metadata == *"<title>Error</title>"* ]]; then
      >&2 echo "Error: Invalid arXiv URL or identifier: ${identifier}"
      exit 1
  fi

  # Extract the relevant information from the metadata using xpath (requires xmllint)
  original_date=$(echo "$metadata" | xmllint --xpath '//*[local-name()="entry"]/*[local-name()="published"]/text()' -)
  latest_date=$(echo "$metadata" | xmllint --xpath '//*[local-name()="entry"]/*[local-name()="updated"]/text()' -)
  title=$(echo "$metadata" | xmllint --xpath '//*[local-name()="entry"]/*[local-name()="title"]/text()' -)
  authors=$(echo "$metadata" | xmllint --xpath '//*[local-name()="entry"]//*[local-name()="author"]/*[local-name()="name"]/text()' - | awk '{print $NF}' | paste -sd "," -)
  latest_version=$(echo "$metadata" | xmllint --xpath '//*[local-name()="entry"]/*[local-name()="id"]/text()' - | grep -oE 'v[0-9]+' | tr -d 'v')

  # Format the dates by extracting the first 10 characters (date in ISO format)
  original_date=${original_date:0:10}
  latest_date=${latest_date:0:10}

  # Shorten the authors names according to the rules
  IFS=',' read -ra authors_array <<< "$authors"
  if [ "${#authors_array[@]}" -ge 4 ]; then
      authors="${authors_array[0]} et al"
  fi

  # Construct the filename according to the format
  filename="$original_date"
  if [ "$latest_version" != "1" ]; then
      filename+=" ($latest_date v$latest_version)"
  fi
  filename+=" - $authors - $title.pdf"

  # Download the PDF
  curl -sS "https://arxiv.org/pdf/$identifier.pdf" --output "$save_to/$filename"

  echo "Downloaded PDF as: $filename"
}

download_arxiv_PDF "$@"
