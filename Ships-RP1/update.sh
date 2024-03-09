#!/bin/bash -

bd='../../../saves/RP-1/SHIPS'
( cd "$bd"; find . -iname temp.craft -o -iname \*.craft -print0) | xargs -0 tar cf - -C "$bd" | tar xpvf -
