#!/usr/bin/env python

import argparse
import itertools
import json
import logging
import math
import os
import socket
import time
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
    parser.add_argument("-P", "--playlist", action=EnvDefault, envvar="PLAYLIST")
    parser.add_argument(
        "-f", "--frequency", default=0, type=int, action=EnvDefault, envvar="FREQUENCY"
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

    queue_changed_cache = ""

    logging.info("Waiting 30 seconds before starting")
    time.sleep(30)

    urlsplit = urllib.parse.urlsplit(args.url)
    host = urlsplit.netloc
    port = urlsplit.port or (443 if urlsplit.netloc == "https" else 80)

    logging.info(f"Waiting for connection to {host}:{port}")
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    navidrome_open = sock.connect_ex((host, port))
    while navidrome_open != 0:
        navidrome_open = sock.connect_ex((host, port))

    logging.info("Waiting for navidrome to be ready")
    navidrome_status = navidrome_request(args.url, "ping", args.username, args.password)
    while navidrome_status["status"] != "ok":
        time.sleep(10)
        navidrome_status = navidrome_request(
            args.url, "ping", args.username, args.password
        )

    while True:
        logging.info("Getting play queue")
        play_queue = navidrome_request(
            args.url, "getPlayQueue", args.username, args.password
        )

        queue_changed = play_queue["playQueue"]["changed"]
        if queue_changed_cache != "" and queue_changed_cache == queue_changed:
            logging.info("No change to queue since last run")
            logging.info(f"Waiting {args.frequency} seconds until next run")
            time.sleep(args.frequency)
            continue

        queue_changed_cache = queue_changed

        play_queue_tracks = [i["id"] for i in play_queue["playQueue"]["entry"]]
        current_play_queue_track = play_queue["playQueue"]["current"]

        play_queue_tracks = play_queue_tracks[
            play_queue_tracks.index(current_play_queue_track) :
        ]

        logging.info("Getting playlists")
        r = navidrome_request(args.url, "getPlaylists", args.username, args.password)
        playlists = r["playlists"]["playlist"]

        playlist_search = [i["id"] for i in playlists if i["name"] == args.playlist]

        if playlist_search:
            logging.info(f"{args.playlist} playlist found")
            playlist_id = playlist_search[0]
        else:
            logging.info(f"{args.playlist} playlist not found, creating new")
            playlist_new = navidrome_request(
                args.url,
                "createPlaylist",
                args.username,
                args.password,
                name=args.playlist,
            )
            playlist_id = playlist_new["playlist"]["id"]

        playlist = navidrome_request(
            args.url, "getPlaylist", args.username, args.password, id=playlist_id
        )
        if "entry" in playlist["playlist"]:
            logging.info("Clearing playlist")
            for i in range(math.ceil(len(playlist["playlist"]["entry"]) / 200)):
                navidrome_request(
                    args.url,
                    "updatePlaylist",
                    args.username,
                    args.password,
                    playlistId=playlist_id,
                    songIndexToRemove=range(0, 200),
                )

        logging.info("Adding queue tracks to playlist")
        for batch in itertools.batched(play_queue_tracks, n=200):
            navidrome_request(
                args.url,
                "updatePlaylist",
                args.username,
                args.password,
                playlistId=playlist_id,
                songIdToAdd=batch,
            )

        if args.frequency == 0:
            break

        logging.info(f"Waiting {args.frequency} seconds until next run")
        time.sleep(args.frequency)


if __name__ == "__main__":
    main()
