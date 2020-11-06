# axi4l_slv

AXI4-Lite slave peripheral example. It meets [AMBA AXI4-Lite protocol specification](https://developer.arm.com/architectures/system-architectures/amba).

## Register/Field Type

- [ ] **IRQ**: IRQ registers are a set of registers to handle interrupt. Including STAT, TRIG, TRAP, MASK, FORCE subfunction registers.
  - [ ] **IRQ**: Field, which should be single bit field

- [ ] **NORMAL**: Normal Register
  - [x] **WR**: Basic write field. IP to fabric. Also readable. Read return written value
  - [ ] **WHS**: Write field with handshake (external request/ack)
  - [ ] **PUT**: Write field with write indicator
  - [ ] **CONST**: Constant (read only register). Simplest case
  - [x] **RO**:Basic read field. Fabric to IP. Not writable. Write takes no effect
  - [ ] **RHS**:Read field with handshake (external request/ack)
  - [ ] **GET**: Read filed with read indicator

- [ ] **MEM**: Memory block
  - [ ] **MEM**: Memory filed

## Advance Features

- [ ] **CDC**

## Open Issues

- Currently a write FSM and a read FSM is used to implement and guarantee the AXI logic meets the specification. However FSM takes 1 or 2 clock ticks to response to the AXI master. Maybe an none FSM logic can reduce the latency. Is it more suitable?

- Mixing some type of fields maybe dangerous.
