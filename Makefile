---

name: CI
on:
  push:
    branches:
      - master

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v2
      - name: Install Go
        uses: actions/setup-go@v2
        with:
          go-version: 1.16.x
      - name: Lint
        run: |
          curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(go env GOPATH)/bin v1.42.1
          make lint
  vet:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v2
      - name: Install Go
        uses: actions/setup-go@v2
        with:
          go-version: 1.16.x
      - name: Vet
        run: make vet

  ineffassign:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v2
      - name: Install Go
        uses: actions/setup-go@v2
        with:
          go-version: 1.16.x
      - name: Lint
        run: make ineffassign

  test:
    runs-on: ubuntu-latest
    steps:
      - name: Install Go
        uses: actions/setup-go@v2
        with:
          go-version: 1.16.x
      - name: Checkout code
        uses: actions/checkout@v2
      - name: Test
        run: make test

  codeql:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        language: [ 'go' ]
    steps:
      - name: Checkout code
        uses: actions/checkout@v2
      - name: Initialize CodeQL
        uses: github/codeql-action/init@v1
        with:
          languages: ${{ matrix.language }}
      # Autobuild attempts to build any compiled languages  (C/C++, C#, or Java).
      # If this step fails, then you should remove it and run the build manually (see below)
      - name: Autobuild
        uses: github/codeql-action/autobuild@v1
      - name: Perform CodeQL Analysis
        uses: github/codeql-action/analyze@v1

  coverage:
    runs-on: ubuntu-latest
    needs:
      - lint
      - vet
      - ineffassign
      - test
      - codeql
    steps:
      - name: Checkout code
        uses: actions/checkout@v2
      - name: Install Go
        uses: actions/setup-go@v2
        with:
          go-version: 1.16.x
      - name: Coverage Test
        run: sudo go test ./... -race -coverprofile=coverage.txt -covermode=atomic
      - name: Coverage Upload
        run: bash <(curl -s https://codecov.io/bash)

  sonarcloud:
    runs-on: ubuntu-latest
    needs:
      - lint
      - vet
      - ineffassign
      - test
      - codeql
    steps:
      - uses: actions/checkout@v2
        with:
          fetch-depth: 0  # Shallow clones should be disabled for a better relevancy of analysis
      - name: Install Go
        uses: actions/setup-go@v2
        with:
          go-version: 1.16.x
      - name: Coverage Test
        run: sudo go test ./... -race -coverprofile=coverage.txt -covermode=atomic
      - name: SonarCloud Scan
        uses: SonarSource/sonarcloud-github-action@master
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}

  build:
    needs:
      - coverage
      - sonarcloud
    strategy:
      matrix:
        os: [ ubuntu-latest, macos-latest ]
    runs-on: ${{ matrix.os }}
    steps:
      - name: Install Go
        uses: actions/setup-go@v2
        with:
          go-version: 1.16.x
      - name: Checkout code
        uses: actions/checkout@v2
      - name: Test
        run: make build

  tag:
    runs-on: ubuntu-latest
    needs:
      - build
    steps:
      - name: Checkout
        uses: actions/checkout@v2
        with:
          fetch-depth: '0'
      - name: Bump version and push tag
        uses: anothrNick/github-tag-action@1.36.0
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          WITH_V: true
          DEFAULT_BUMP: patch

  goreleaser:
    runs-on: ubuntu-latest
    needs:
      - tag
    steps:
      - name: Checkout
        uses: actions/checkout@v2
        with:
          fetch-depth: 0
      - name: Set outputs
        id: vars
        run: |
          echo "::set-output name=latest_tag::$(git describe --tags $(git rev-list --tags --max-count=1))"
          echo "::set-output name=build_time::$(date -u +'%m-%d-%YT%H:%M:%SZ')"
          echo "::set-output name=sha_short::$(git rev-parse --short HEAD)"
      - name: Install Go
        uses: actions/setup-go@v2
        with:
          go-version: 1.16.x
      - name: Run GoReleaser
        uses: goreleaser/goreleaser-action@v2
        with:
          version: latest
          args: release --rm-dist
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      - name: Upload assets
        uses: actions/upload-artifact@v2
        with:
          name: syn-flood
          path: dist/*

  docker:
    runs-on: ubuntu-latest
    needs:
      - tag
    steps:
      - name: Checkout
        uses: actions/checkout@v2
        with:
          fetch-depth: 0

      - name: Get Previous tag
        id: previoustag
        uses: WyriHaximus/github-action-get-previous-tag@v1

      - name: Build the Docker image
        run: docker build . --file Dockerfile --tag bilalcaliskan/syn-flood:${{ steps.previoustag.outputs.tag }}

      - name: Publish to Registry
        uses: elgohr/Publish-Docker-Github-Action@master
        with:
          name: bilalcaliskan/syn-flood
          tags: "latest,${{ steps.previoustag.outputs.tag }}"
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}
