# 🖥️ ARC-OS

A hobby operating system built with **C (Open Watcom)** and **x86 Assembly (NASM)**.  
The project is a personal learning journey into OS development, starting from a custom bootloader and moving toward a working kernel with basic drivers and system functionality.

---

![Build Status](https://img.shields.io/badge/build-passing-brightgreen) 
![License](https://img.shields.io/badge/license-MIT-blue) 
![Emulators](https://img.shields.io/badge/emulators-QEMU%20%7C%20Bochs-orange)

---

## 🚀 Features (Implemented so far)

- **Stage 1 Bootloader** (written in NASM) – loads the next stage into memory  
- **Stage 2 Bootloader (partial)** – extended loading logic and setup groundwork  
- **Custom `printf` implementation** – supports formatted printing to screen  
- **Division routine** implemented to enable `printf` integer formatting  
- Basic console output (`Hello world from C!`) through BIOS interrupts and `printf`

---

## 🔮 Roadmap / Work in Progress

- Complete Stage 2 bootloader  
- Keyboard input driver  
- Basic memory management  
- Simple filesystem support  
- Multitasking support  
- Expand kernel functionality  

This is an active project — features will continue to be added incrementally.

---

## 🧱 Tech Stack

- **x86 Assembly (NASM)** - bootloader and low-level routines
- **C (Open Watcom)** – kernel and higher-level code  
- **GNU Make** – build automation  
- **QEMU** / **Bochs** – emulators for testing  

---

## 🛠️ Setup Instructions

### 1. Clone the repository

```bash
git clone https://github.com/arshdippamma/ARC-OS.git
cd ARC-OS
```

### 2. Install prerequisites

Make sure you have installed:

- `nasm`
- `make`
- **Open Watcom**
- `qemu-system-i386` for testing
- `bochs-x bochsbios vgabios` for debugging

### 3. Build and Run

```
make clean
make
./run.sh
```

This will assemble the bootloader, compile the kernel, link them into a disk image, and run it in your emulator (run.sh uses QEMU).

### 4. Debugging

To start Bochs with the debugger enabled:

```
./debug.sh
```

## 🗂️ Project Structure

```
ARC-OS/
├── src/
│   ├── bootloader/
│   │   └── stage_1/
│   │       └── boot.asm
│   └── kernel/
│       ├── main.c
│       └── ...
├── build/         # Generated binaries and images (ignored in Git)
├── run.sh         # Script to run OS in QEMU
├── debug.sh       # Script to debug OS in Bochs
├── Makefile
└── README.md
```

## 📌 Notes

- All generated binaries, object files, and images (.bin, .img, .o, .exe, etc.) are excluded from version control.
- Development is currently in **16-bit real mode** for the bootloader, with preparation for transitioning into **32-bit protected mode**.
- This project is primarily educational and experimental. Stability is not guarunteed.

## 📚 Resources

- [OSDev Wiki](https://wiki.osdev.org/Expanded_Main_Page)
- [Open Watcom Documentation](https://open-watcom.github.io/open-watcom-v2-wikidocs/ctools.pdf)
- [Ralf Brown's Interrup List](https://www.ctyme.com/rbrown.htm)
- [Philipp Oppermann's Blog](https://os.phil-opp.com/)
- [QEMU Documentation](https://www.qemu.org/docs/master/)
- [Bochs Documentation](https://bochs.sourceforge.io/doc/docbook/)
- [nanobyte OS development YouTube series](https://www.youtube.com/playlist?list=PLFjM7v6KGMpiH2G-kT781ByCNC_0pKpPN)

## 📄 License

MIT License. Feel free to modify, improve, and share.

## 🙌 Acknowledgments

- OSDev Wiki
- Open Watcom contributors
- QEMU/Bochs team for emulation and debugging tools
- nanobyte YouTube channel