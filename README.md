# axi4l_slv

AXI4-Lite slave peripheral example. It meets [AMBA AXI4-Lite protocol specification](https://developer.arm.com/architectures/system-architectures/amba).

## Register/Field Type

- [x] **IRQ**: IRQ registers are a set of registers to handle interrupt. Including STAT, TRIG, TRAP, MASK, FORCE subfunction registers
  - [x] **IRQ**: IRQ Field

- [x] **NORMAL**: Normal Register
  - [x] **RW**: Basic write field. IP to fabric. Also readable. Read return written value
  - [x] **RO**:Basic read field. Fabric to IP. Not writable. Write takes no effect

- [ ] **MEM**: Memory block
  - [ ] **MEM**: Memory filed

## Limitations

- Currently write/read FSM are used to implement and guarantee the logic meets the specification. However FSM takes few clock ticks to response to the AXI master, which may limit the maximum throughput of bus.

- Multiple outstanding transactions is not supported. It's restricted by the handshake signals.
