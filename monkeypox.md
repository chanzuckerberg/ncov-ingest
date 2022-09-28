How to download monkeypox:

```
pip install xopen pandas regex
./bin/fetch-from-genbank > monkeypox.ndjson
./bin/transform-genbank monkeypox.ndjson --output-metadata mpx-metadata.tsv --output-fasta mpx.fasta > flagged
```

The file that generates the query against genbank is `bin/genbank-url`
