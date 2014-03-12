Tone
====

Drives a piezo speaker with beeps for music.

Contributors
============

- [Matt Haines](https://twitter.com/beardedinventor)

Example Code
============

```
// 1 = full note, 2 = half note, 4 = quarter note, ...
Scale <- [
    { note = NOTE_C7, duration = 4 },
    { note = NOTE_CS7, duration = 4 },
    { note = NOTE_D7, duration = 4 },
    { note = NOTE_DS7, duration = 4 },
    { note = NOTE_E7, duration = 4 },
    { note = NOTE_F7, duration = 4 },
    { note = NOTE_FS7, duration = 4 },
    { note = NOTE_G7, duration = 4 },
    { note = NOTE_GS7, duration = 4 },
    { note = NOTE_A7, duration = 4 },
    { note = NOTE_AS7, duration = 4 },
    { note = NOTE_B7, duration = 4 }
];

Piezo <- Tone(hardware.pin8);
scale <- Song(Piezo, Scale);
scale.Play();
```

