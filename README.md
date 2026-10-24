# Stitch-Tracker
An FPGA-based crochet stitch tracker (VHDL) consisting of an OLED for pattern display, a rotary encoder for navigation, and a capacitive-touch advance.  

When working on a complex pattern it's easy to lose track of stitch count, and retracing or recounting breaks the flow. This counter combines a counter with an updating pattern, giving the user a complete idea of where they are in the pattern, cutting out other distractions. *(Built for Rutgers Embedded Systems 2026)*

**Highlights**
- OLED that shows the current row, stitch and yarn color, and the next stitch and its color
- Capacitive touch button that advances the pattern, requiring little force or precision
- Rotary encoder that lets you scroll forward or back through the patten
- Multi-module VHDL system: pattern ROM and position FSM, quadrature encoder decoder, touch input synchronizer, and OLED controller
- Single-cycle datapath
- Small footprint: 220 LUTs (1.25%), 281 flip-flops (0.80%), and about 0.1 W total on-chip power

https://github.com/mirnak524/Stitch-Tracker/blob/main/assets/demo.mov

## How it Works
![Block Diagram](assets/Stitch%20Block.svg)
| Module | Role |
| `stitch_top` | Top level that wires everything together |
| `stitch_ctrl` | Holds the pattern ROM, tracks current position, outputs current and next stitch codes and colors, and flags when the pattern is done |
| `enc_decoder` | Decodes the encoder's A/B quadrature signals into clockwise and counterclockwise pulses |
| `cdc_touch` | Synchronizes the asynchronous touch input and filters repeat triggers |
| `debounce` | Debounces mechanical inputs (button 0 is reset) |
| `oled_ctrl` | Drives the OLED over SPI with 4-row x 16-character buffer and display initialization sequence |

**Controls:** one touch on the capacitive button advances one stitch. Turning the encoder clockwise advances and counterclockwise goes back. Button 0 resets, and LED0 lights at the end of the pattern

**Pin mapping:** OLED on PMOD JA, rotary encoder on JB, touch button on JC, 125 MHz system clock. 

## Improvements
The design was originally made with gesture recognition in mind so the pattern would automatically progress, and the accelerometer path was made. The intention was to integrate an ADXL345 over SPI, with the data sent over UART to a Python script. This data never came back usable, so the project pivoted to the touch button advancement. 

![FSM](assets/Stitch%20Tracker.svg)
