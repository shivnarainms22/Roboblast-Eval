# Task: Restore the grenade's detonation

## Context

This project, **RoboBlast**, is a third-person shooter made in Godot. The player
can throw grenades: a grenade arcs through the air, bounces off the ground, and
after a short fuse it goes off with an explosion sound.

Right now the detonation does **nothing** beyond that sound. The grenade simply
disappears — it has no effect on the world and produces no visual. Your job is to
make a grenade actually **explode** when it goes off.

## What the detonation must do

When a grenade detonates:

1. **It damages nearby enemies.**
   Enemies caught in the blast are hit and knocked back / defeated. Enemies close
   to where the grenade goes off are caught; enemies well outside the blast are
   left unaffected. The blast reaches roughly a few metres around the detonation
   point — a local blast, not the whole level.

2. **It produces a brief fiery blast at the point of impact.**
   A bright, fiery (orange) burst appears right where the grenade goes off. It
   flares and expands outward from that point, then quickly dies away. The whole
   effect is short-lived — over in a fraction of a second — and leaves nothing
   behind once it has finished. It should read, on screen, as an explosion:
   bright and hot-coloured, centred on the impact point, expanding, and then gone.

## Notes

- You are restoring **what the detonation does**. The grenade already throws,
  arcs, bounces, and triggers its own detonation (with the sound) — that part
  works.
- You will be judged on the **observable result** — what happens to enemies in
  the game, and what the blast looks like on screen — not on any particular way
  of building it. There are many valid implementations.
- Play the game and inspect the project to understand how it is put together.
