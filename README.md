# Stitch-Tracker
An FPGA-based crochet stitch tracker (VHDL) consisting of an OLED for pattern display, a rotary encoder for navigation, and a capacitive-touch advance.  

When working on a complex pattern it's easy to lose track of stitch count, and retracing or recounting breaks the flow. This counter combines a counter with an updating pattern, giving the user a complete idea of where they are in the pattern, cutting out other distractions.

**Highlights**
- OLED that shows the current row, stitch and yarn color, and the next stitch and its color
- Capacitive touch button that advances the pattern, requiring little force or precision
- Rotary encoder that lets you scroll forward or back through the patten
- Multi-module VHDL system: pattern ROM and position FSM, quadrature encoder decoder, touch input synchronizer, and OLED controller
- Single-cycle datapath
- Small footprint: 220 LUTs (1.25%), 281 flip-flops (0.80%), and about 0.1 W total on-chip power

## How it Works
