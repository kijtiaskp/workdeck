"""Algorithmic soundtrack for the Workdeck intro video.

Every sound is synthesized from oscillators and noise, and every hit is placed
on the same timeline as the WebGL scene (see the timeline in scene.js).
"""

import sys
import wave

import numpy as np

SAMPLE_RATE = 44_100
DURATION = 48.0
BPM = 120
BEAT = 60 / BPM
BAR = BEAT * 4
SAMPLE_COUNT = int(SAMPLE_RATE * DURATION)

# One chord per bar: Gmaj7, A6, F#m7, Bm9.
PROGRESSION = [
    {"root": 43, "notes": [55, 59, 62, 66]},
    {"root": 45, "notes": [57, 61, 64, 66]},
    {"root": 42, "notes": [54, 57, 61, 64]},
    {"root": 47, "notes": [59, 62, 66, 69, 73]},
]

# Scene boundaries and UI events, in seconds, mirrored from scene.js.
SCENE_CUTS = [6.0, 14.0, 22.0, 32.0, 42.0]
ROW_POPS = [11.2 + i * 0.23 for i in range(6)] + [14.6 + i * 0.24 for i in range(5)]
BADGE_POPS = [15.8 + i * 0.32 for i in range(5)]
STATUS_POPS = [22.5 + i * 0.17 for i in range(9)]
CHIP_WHOOSH = 25.0
RUN_CLICK = 34.1
SPINNER_START, SPINNER_END = 34.35, 35.8
RUN_STARTED = 35.8
LOG_LINES = [37.6 + i * 0.3 for i in range(12)]

rng = np.random.default_rng(42)


def midi_to_hz(note):
    return 440.0 * 2 ** ((note - 69) / 12)


def seconds(value):
    return int(value * SAMPLE_RATE)


def time_axis(length):
    return np.arange(length) / SAMPLE_RATE


def lowpass(signal, cutoff):
    spectrum = np.fft.rfft(signal)
    frequencies = np.fft.rfftfreq(len(signal), 1 / SAMPLE_RATE)
    spectrum /= np.sqrt(1 + (frequencies / cutoff) ** 4)
    return np.fft.irfft(spectrum, len(signal))


def highpass(signal, cutoff):
    return signal - lowpass(signal, cutoff)


def envelope(length, attack, release):
    curve = np.ones(length)
    attack_samples = min(seconds(attack), length)
    release_samples = min(seconds(release), length)
    if attack_samples:
        curve[:attack_samples] = np.linspace(0, 1, attack_samples)
    if release_samples:
        curve[-release_samples:] *= np.linspace(1, 0, release_samples)
    return curve


def place(track, sound, start, gain=1.0):
    begin = seconds(start)
    if begin >= len(track):
        return
    end = min(len(track), begin + len(sound))
    track[begin:end] += sound[: end - begin] * gain


def saw(frequency, length, harmonics=14, detune_cents=0.0):
    t = time_axis(length)
    frequency *= 2 ** (detune_cents / 1200)
    wave_sum = np.zeros(length)
    for n in range(1, harmonics + 1):
        if frequency * n > SAMPLE_RATE / 2:
            break
        wave_sum += np.sin(2 * np.pi * frequency * n * t + n * 0.7) / n
    return wave_sum


def pad_voice(note, length):
    voice = sum(saw(midi_to_hz(note), length, detune_cents=cents) for cents in (-8, 0, 8))
    return voice * envelope(length, 0.7, 0.9)


def pluck(note, length=0.5):
    samples = seconds(length)
    t = time_axis(samples)
    frequency = midi_to_hz(note)
    tone = np.sin(2 * np.pi * frequency * t) + 0.35 * np.sin(4 * np.pi * frequency * t) + 0.12 * np.sin(6 * np.pi * frequency * t)
    return tone * np.exp(-t * 9) * envelope(samples, 0.002, 0.05)


def bell(note, length=2.5):
    samples = seconds(length)
    t = time_axis(samples)
    frequency = midi_to_hz(note)
    partials = [(1, 1.0, 2.2), (2.76, 0.45, 3.5), (5.4, 0.25, 5.5), (8.9, 0.12, 8)]
    tone = sum(amplitude * np.sin(2 * np.pi * frequency * ratio * t) * np.exp(-t * decay) for ratio, amplitude, decay in partials)
    return tone * envelope(samples, 0.003, 0.2)


def kick(length=0.45):
    samples = seconds(length)
    t = time_axis(samples)
    frequency = 48 + 110 * np.exp(-t * 32)
    phase = 2 * np.pi * np.cumsum(frequency) / SAMPLE_RATE
    return np.tanh(np.sin(phase) * np.exp(-t * 7) * 1.6)


def clap(length=0.25):
    samples = seconds(length)
    t = time_axis(samples)
    noise = highpass(lowpass(rng.standard_normal(samples), 2400), 900)
    bursts = sum(np.exp(-np.maximum(t - offset, 0) * 60) * (t >= offset) for offset in (0, 0.011, 0.022))
    return noise * (bursts * 0.6 + np.exp(-t * 18) * 0.5)


def hat(length=0.06):
    samples = seconds(length)
    return highpass(rng.standard_normal(samples), 7000) * np.exp(-time_axis(samples) * 70)


def ui_blip(pitch=1760, length=0.09):
    samples = seconds(length)
    t = time_axis(samples)
    return np.sin(2 * np.pi * pitch * t * (1 + 0.4 * np.exp(-t * 60))) * np.exp(-t * 45)


def click(length=0.03):
    samples = seconds(length)
    t = time_axis(samples)
    return highpass(rng.standard_normal(samples), 3000) * np.exp(-t * 250) + np.sin(2 * np.pi * 2200 * t) * np.exp(-t * 180) * 0.6


def riser(length=2.0):
    samples = seconds(length)
    t = time_axis(samples)
    noise = rng.standard_normal(samples)
    bands = [lowpass(noise, cutoff) for cutoff in (400, 1500, 5000, 12000)]
    position = (t / length) * (len(bands) - 1)
    mixed = np.zeros(samples)
    for index, band in enumerate(bands):
        mixed += band * np.clip(1 - np.abs(position - index), 0, 1)
    return mixed * (t / length) ** 2.2


def impact(length=2.2):
    samples = seconds(length)
    t = time_axis(samples)
    frequency = 32 + 60 * np.exp(-t * 4)
    phase = 2 * np.pi * np.cumsum(frequency) / SAMPLE_RATE
    boom = np.sin(phase) * np.exp(-t * 2.2)
    air = lowpass(rng.standard_normal(samples), 3000) * np.exp(-t * 6) * 0.35
    return np.tanh((boom + air) * 1.4)


def whoosh(length=1.2):
    samples = seconds(length)
    t = time_axis(samples)
    noise = rng.standard_normal(samples)
    shape = np.sin(np.pi * t / length) ** 2
    return (lowpass(noise, 2500) * 0.7 + highpass(noise, 6000) * 0.2) * shape


def reverb(signal, seconds_long=2.4, wet=0.25):
    samples = seconds(seconds_long)
    t = time_axis(samples)
    impulse = rng.standard_normal(samples) * np.exp(-t * 3.2)
    impulse = lowpass(impulse, 6000)
    impulse /= np.sqrt(np.sum(impulse**2))
    size = 1 << int(np.ceil(np.log2(len(signal) + samples)))
    tail = np.fft.irfft(np.fft.rfft(signal, size) * np.fft.rfft(impulse, size), size)[: len(signal)]
    return signal * (1 - wet) + tail * wet


def section_level(time, points):
    return np.interp(time, [p[0] for p in points], [p[1] for p in points])


def build():
    t = time_axis(SAMPLE_COUNT)
    pad = np.zeros(SAMPLE_COUNT)
    bass = np.zeros(SAMPLE_COUNT)
    arp = np.zeros(SAMPLE_COUNT)
    drums = np.zeros(SAMPLE_COUNT)
    effects = np.zeros(SAMPLE_COUNT)
    ui = np.zeros(SAMPLE_COUNT)
    kick_times = []

    bar_count = int(DURATION / BAR)
    for bar in range(bar_count):
        start = bar * BAR
        chord = PROGRESSION[bar % len(PROGRESSION)]
        length = seconds(BAR + 1.0)
        for note in chord["notes"]:
            place(pad, pad_voice(note, length), start, 0.05)

        for step in range(8):
            note = chord["root"] + (12 if step % 4 == 3 else 0)
            tone = saw(midi_to_hz(note), seconds(BEAT / 2), harmonics=6)
            place(bass, np.tanh(tone * 1.5) * envelope(len(tone), 0.005, 0.08), start + step * BEAT / 2, 0.22)

        arp_notes = chord["notes"] + [n + 12 for n in chord["notes"]]
        for step in range(16):
            direction = step if (bar // 2) % 2 == 0 else 15 - step
            note = arp_notes[direction % len(arp_notes)] + 12
            place(arp, pluck(note), start + step * BEAT / 4, 0.13 if step % 4 == 0 else 0.08)

        for beat in range(4):
            beat_time = start + beat * BEAT
            groove_full = 14 <= beat_time < 33.5 or 36 <= beat_time < 42
            groove_light = 6 <= beat_time < 14 and beat % 2 == 0
            if groove_full or groove_light:
                place(drums, kick(), beat_time, 0.85)
                kick_times.append(beat_time)
            if groove_full and beat % 2 == 1:
                place(drums, clap(), beat_time, 0.35)
            if 6 <= beat_time < 42 and not (33.5 <= beat_time < 35.8):
                place(drums, hat(), beat_time + BEAT / 2, 0.16)
                if groove_full:
                    place(drums, hat(0.03), beat_time + BEAT * 0.75, 0.07)

    # Sidechain: duck the pad and bass after every kick.
    duck = np.ones(SAMPLE_COUNT)
    release = seconds(0.3)
    shape = 1 - 0.55 * np.exp(-np.linspace(0, 5, release))
    for kick_time in kick_times:
        begin = seconds(kick_time)
        end = min(SAMPLE_COUNT, begin + release)
        duck[begin:end] = np.minimum(duck[begin:end], shape[: end - begin])

    # Lead bell melody over the environments scene.
    melody = [(22.0, 78), (23.0, 76), (24.0, 74), (25.5, 73), (26.0, 71), (28.0, 74), (29.0, 76), (30.0, 78), (31.0, 81)]
    for start, note in melody:
        place(effects, bell(note), start, 0.09)

    for cut in SCENE_CUTS:
        place(effects, riser(), cut - 2.0, 0.12)
        place(effects, impact(), cut, 0.5 if cut in (6.0, 22.0) else 0.3)
    place(effects, whoosh(), CHIP_WHOOSH - 0.1, 0.25)
    place(effects, riser(1.45), SPINNER_START, 0.14)
    place(effects, impact(), RUN_STARTED, 0.55)
    place(effects, bell(86, 3.0), RUN_STARTED, 0.08)

    for pop_time in ROW_POPS:
        place(ui, ui_blip(1568), pop_time, 0.10)
    for index, pop_time in enumerate(BADGE_POPS):
        place(ui, ui_blip(1760 + index * 110), pop_time, 0.11)
    for index, pop_time in enumerate(STATUS_POPS):
        place(ui, ui_blip(1318 + (index % 4) * 196), pop_time, 0.08)
    place(ui, click(), RUN_CLICK, 0.5)
    spinner_tick = SPINNER_START
    while spinner_tick < SPINNER_END:
        place(ui, click(0.02), spinner_tick, 0.12)
        spinner_tick += BEAT / 4
    for line_time in LOG_LINES:
        place(ui, click(0.015), line_time, 0.09)

    # Final chord: a bell voicing of Gmaj7 that rings out under the title.
    for index, note in enumerate([67, 71, 74, 78, 83]):
        place(effects, bell(note, 4.5), 44.0 + index * 0.06, 0.07)

    pad_level = section_level(t, [(0, 0), (1.5, 0.8), (6, 1), (33.5, 1), (34.2, 0.45), (35.8, 1), (42, 1), (46.5, 0.7), (48, 0)])
    groove_level = section_level(t, [(0, 0), (5.9, 0), (6.0, 0.6), (13.9, 0.6), (14.0, 1), (33.4, 1), (34.0, 0.2), (35.8, 1), (41.8, 1), (42.2, 0), (48, 0)])
    arp_level = section_level(t, [(0, 0), (6, 0), (7, 0.7), (14, 1), (33.5, 1), (34.2, 0.3), (35.8, 1), (42, 0.6), (45, 0), (48, 0)])

    pad = lowpass(pad, 2600) * pad_level * duck
    bass = lowpass(bass, 900) * groove_level * duck
    arp = arp * arp_level
    drums = drums * np.maximum(groove_level, 0.0)

    music = pad + bass + arp + drums + effects + ui
    left = reverb(music + arp * 0.3, wet=0.28)
    right = reverb(music + pad * 0.2, wet=0.28)

    stereo = np.stack([left, right], axis=1)
    fade_in = np.clip(t / 0.4, 0, 1)
    fade_out = np.clip((DURATION - t) / 2.5, 0, 1)
    stereo *= (fade_in * fade_out)[:, None]
    stereo = np.tanh(stereo * 1.2)
    stereo *= 10 ** (-1 / 20) / np.max(np.abs(stereo))
    return stereo


def write_wav(path, stereo):
    pcm = (stereo * 32767).astype("<i2")
    with wave.open(path, "wb") as file:
        file.setnchannels(2)
        file.setsampwidth(2)
        file.setframerate(SAMPLE_RATE)
        file.writeframes(pcm.tobytes())


if __name__ == "__main__":
    output = sys.argv[1] if len(sys.argv) > 1 else "out/soundtrack.wav"
    write_wav(output, build())
    print(f"wrote {output}")
