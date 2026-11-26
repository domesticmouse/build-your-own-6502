# Build your own 6502

A study repository and interactive course for the **[Our Own 6502, Gate by Gate](https://www.youtube.com/playlist?list=PLUe5uP3A3_Vw)** video series by **Yves Robert** ([Gate by Gate](https://www.youtube.com/@gatebygate)), building a 6502 processor and 320×200 HDMI computer system from scratch in Verilog on a Sipeed Tang Nano 20K FPGA.

- **Detailed Curriculum & Episode Notes:** [curriculum.md](curriculum.md)
- **Course Mission:** [MISSION.md](MISSION.md)
- **Curated Resources:** [RESOURCES.md](RESOURCES.md)
- **Upstream Reference Repository:** [yvesrob/6502-gate-by-gate](https://github.com/yvesrob/6502-gate-by-gate)

## Interactive Course Site

- **Live Course Site:** [https://domesticmouse.github.io/build-your-own-6502/](https://domesticmouse.github.io/build-your-own-6502/)
- **License:** [LICENSE](LICENSE)

Build and validate the static HTML lessons and reference sheets locally:

```bash
.venv/bin/python build.py --check
```

### Published Lessons
- [Lesson 0001: FPGA Toolchain Setup, First Logic Gate & Blinking LED](lessons/0001-fpga-toolchain-environment.md) ([companion app](apps/0001-fpga-toolchain-environment/))

### Reference Sheets
- [Glossary of FPGA & 6502 Hardware Terms](reference/GLOSSARY.md)
- [FPGA & 6502 Toolchain Cheat Sheet](reference/toolchain-cheatsheet.md)

## Episodes

Here is the list of all **28 videos** in the playlist **[Our Own 6502, Gate by Gate](https://www.youtube.com/playlist?list=PLUe5uP3A3_Vw)** by **[Gate by Gate](https://www.youtube.com/@gatebygate)**:

1. [I'm Rebuilding the 6502 from Scratch, One Gate at a Time | Episode 1](https://www.youtube.com/watch?v=czPMjs0Y0zc) (19:55)
2. [How a Computer Adds: I Built an Adder from Just Two Logic Gates | Episode 2](https://www.youtube.com/watch?v=oW3Ts-unUhM) (20:38)
3. [I Built an 8-Bit Adder and Tested Every Possible Addition | Episode 3](https://www.youtube.com/watch?v=P7UMo3etuU0) (20:14)
4. [How a Chip Remembers: I Built Memory from Scratch, One Bit at a Time | Episode 4](https://www.youtube.com/watch?v=rFxJn-Mws8s) (27:35)
5. [How a Screen Is Really Drawn: One Pixel at a Time, with Two Counters | Episode 5](https://www.youtube.com/watch?v=6d8R3dYR4KQ) (25:16)
6. [The Missing Clock: How a PLL Turns 27 MHz into 25.2 MHz | Episode 6](https://www.youtube.com/watch?v=SuOi-peTmv8) (14:48)
7. [How HDMI Really Works: I Sent a Picture from an FPGA to a Real Monitor | Episode 7](https://www.youtube.com/watch?v=bCDtCYCuRQ8) (27:18)
8. [Our 6502 Computer Gets a Video Card: 320x200, 16 Colors | Episode 8](https://www.youtube.com/watch?v=DH__9-V3owI) (26:41)
9. [Our First 6502 Program: Machine Code, Assembled by Hand | Episode 9](https://www.youtube.com/watch?v=tfPIlLQfTQE) (24:53)
10. [Assembling Our First 6502 Program with ca65 and ld65 | Episode 10](https://www.youtube.com/watch?v=GZObLHEx75E) (22:50)
11. [ROM, RAM and the Bus for Our 6502 Computer, in Verilog | Episode 11](https://www.youtube.com/watch?v=DwrVhG-ZAuk) (22:49)
12. [Our Own 6502 in Verilog: Writing the First Lines of the Processor | Episode 12](https://www.youtube.com/watch?v=laCEMFvLe48) (22:57)
13. [Writing the ALU of Our Own 6502 in Verilog | Episode 13](https://www.youtube.com/watch?v=Pn0TVKFSsGY) (24:15)
14. [The Four Flags of Our 6502's ALU, in Verilog | Episode 14](https://www.youtube.com/watch?v=MwEeMDGKOW0) (25:03)
15. [Teaching Our 6502 Its First Five Instructions, in Verilog | Episode 15](https://www.youtube.com/watch?v=NZRr0N38ymg) (24:57)
16. [Our Own 6502 Runs Its First Program, in Verilog | Episode 16](https://www.youtube.com/watch?v=je0NqV8yfb4) (25:07)
17. [Our Own 6502 Runs on a Real FPGA Board | Episode 17](https://www.youtube.com/watch?v=e21AEbZTxCE) (25:02)
18. [Our Own 6502 Learns to Read Its RAM, in Verilog | Episode 18](https://www.youtube.com/watch?v=QDbL4oOUd-M) (23:24)
19. [Our Own 6502 Reads a Table from ROM, in Verilog | Episode 19](https://www.youtube.com/watch?v=Z1L8UaTJ3Ws) (25:05)
20. [Our Own 6502 Has the Famous JMP Bug, in Verilog | Episode 20](https://www.youtube.com/watch?v=JP83MuAPz1c) (24:32)
21. [Our Own 6502 Learns to Subtract and Compare, in Verilog | Episode 21](https://www.youtube.com/watch?v=o4232URQ6RU) (23:39)
22. [Our Own 6502 Learns Decimal Mode, in Verilog | Episode 22](https://www.youtube.com/watch?v=ypEmDloKumQ) (26:46)
23. [Our Own 6502 Passes 1.23 Million Tests, in Verilog | Episode 23](https://www.youtube.com/watch?v=kWXux4pb_uY) (19:22)
24. [Our Own 6502 Learns to Branch, in Verilog | Episode 24](https://www.youtube.com/watch?v=4ph7DlMaBhc) (17:52)
25. [Our Own 6502 Learns to Decide, in Verilog | Episode 25](https://www.youtube.com/watch?v=s_aeZwSN6Dg) (23:35)
26. [Our Own 6502 Branches Across a Page, in Verilog | Episode 26](https://www.youtube.com/watch?v=tZYV6iuu1F4) (19:24)
27. [Our Own 6502 Gets a Stack, in Verilog | Episode 27](https://www.youtube.com/watch?v=L1c6EJLveS8) (16:37)
28. [One Missing PLA, and Our Own 6502 Gets Lost | Episode 28](https://www.youtube.com/watch?v=C9miyObRPTw) (28:44)
