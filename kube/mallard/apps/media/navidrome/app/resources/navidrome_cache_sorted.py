#!/usr/bin/env python

import argparse
import datetime
import json
import logging
import os
import pathlib
import sys
import urllib.parse
import urllib.request


class EnvDefault(argparse.Action):
    def __init__(self, envvar, required=True, default=None, **kwargs):
        if envvar:
            if envvar in os.environ:
                default = os.environ[envvar]
        if required and (default is not None):
            required = False
        super(EnvDefault, self).__init__(default=default, required=required, **kwargs)

    def __call__(self, parser, namespace, values, option_string=None):
        setattr(namespace, self.dest, values)


def parse_args():
    parser = argparse.ArgumentParser(
        prog="navidrome_queue_to_playlist",
        description="Create playlist from navidrome queue",
    )
    parser.add_argument("-U", "--url", action=EnvDefault, envvar="URL")
    parser.add_argument("-u", "--username", action=EnvDefault, envvar="USERNAME")
    parser.add_argument("-p", "--password", action=EnvDefault, envvar="PASSWORD")
    parser.add_argument("-c", "--cache-file", action=EnvDefault, envvar="CACHE_FILE")
    parser.add_argument(
        "-t", "--cache-time", action=EnvDefault, envvar="CACHE_TIME", type=int
    )

    return parser.parse_args()


def navidrome_request(url, endpoint, username, password, **extra):
    params = {
        "u": username,
        "p": password,
        "v": "1.16.1",
        "c": "queue2pl",
        "f": "json",
    } | extra
    url_params = urllib.parse.urlencode(params, doseq=True)
    url = f"{url}/rest/{endpoint}?{url_params}"

    with urllib.request.urlopen(url) as req:
        j = json.loads(req.read())
        return j["subsonic-response"]


def main():
    logging.basicConfig(
        level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s"
    )

    args = parse_args()

    logging.info("Fetching playlists ids")
    playlist_info = navidrome_request(
        args.url, "getPlaylists", args.username, args.password
    )

    playlist_changed = max(
        i["changed"]
        for i in playlist_info["playlists"]["playlist"]
        if i["name"].startswith("genre/") or i["name"].startswith("genre/")
    )

    cache_backoff_dt = (
        datetime.datetime.now() - datetime.timedelta(minutes=args.cache_time)
    ).isoformat()

    if playlist_changed < cache_backoff_dt:
        logging.info(
            f"Playlists not updated in last {args.cache_time} minutes, exiting"
        )
        sys.exit()

    genre_playlists = [
        (i["name"], i["id"])
        for i in playlist_info["playlists"]["playlist"]
        if i["name"].startswith("genre/") and not i["name"].startswith("genre/#")
    ]

    ratings_playlists = [
        (i["name"], i["id"])
        for i in playlist_info["playlists"]["playlist"]
        if i["name"].startswith("rating/") and not i["name"].startswith("rating/#")
    ]

    cache_file = pathlib.Path(args.cache_file)
    if cache_file.exists():
        cache = json.loads(cache_file.read_text())
    else:
        cache = {}

    if "genre" not in cache:
        cache["genre"] = {}

    for playlist_name, _ in genre_playlists:
        if playlist_name not in cache["genre"]:
            cache["genre"][playlist_name] = []

    for playlist_name, playlist_id in genre_playlists:
        logging.info(f"Fetching playlist: {playlist_name}")
        p = navidrome_request(
            args.url, "getPlaylist", args.username, args.password, id=playlist_id
        )

        if "entry" not in p["playlist"]:
            continue

        for entry in p["playlist"]["entry"]:
            cache_entry = " ".join(
                str(entry[k])
                for k in [
                    "displayAlbumArtist",
                    "album",
                    "year",
                    "discNumber",
                    "track",
                    "title",
                ]
                if k in entry
            )
            if cache_entry not in cache["genre"][playlist_name]:
                cache["genre"][playlist_name] += [cache_entry]

    if "ratings" not in cache:
        cache["ratings"] = {}

    for playlist_name, _ in ratings_playlists:
        if playlist_name not in cache["ratings"]:
            cache["ratings"][playlist_name] = []

    for playlist_name, playlist_id in ratings_playlists:
        logging.info(f"Fetching playlist: {playlist_name}")

        p = navidrome_request(
            args.url, "getPlaylist", args.username, args.password, id=playlist_id
        )

        if "entry" not in p["playlist"]:
            continue

        for entry in p["playlist"]["entry"]:
            cache_entry = " ".join(
                str(entry[k])
                for k in ["displayAlbumArtist", "album", "year"]
                if k in entry
            )
            if cache_entry not in cache["ratings"][playlist_name]:
                cache["ratings"][playlist_name] += [cache_entry]

    cache_file.write_text(json.dumps(cache, indent=4))


if __name__ == "__main__":
    main()
