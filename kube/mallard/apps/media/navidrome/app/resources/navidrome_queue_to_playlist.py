#!/usr/bin/env python

import argparse
import datetime
import itertools
import json
import logging
import math
import os
import socket
import sys
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

    logging.info("Getting play queue")
    play_queue = navidrome_request(
        args.url, "getPlayQueue", args.username, args.password
    )

    queue_changed = play_queue["playQueue"]["changed"]
    cache_backoff_dt = (
        datetime.datetime.now() - datetime.timedelta(minutes=args.cache_time)
    ).isoformat()

    if queue_changed < cache_backoff_dt:
        logging.info(f"Queue not updated in last {args.cache_time} minutes, exiting")
        sys.exit()

    play_queue_tracks = [i["id"] for i in play_queue["playQueue"]["entry"]]

    if "current" in play_queue["playQueue"]:
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


if __name__ == "__main__":
    main()
