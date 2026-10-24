# SmlEx

Decoder for **SML (Smart Message Language)** telegrams in pure Elixir, built on
binary pattern matching.

SML ([BSI TR-03109-1](https://www.bsi.bund.de/)) is the protocol German
electricity meters ("moderne Messeinrichtung", eHZ) send on their optical
interface. With an IR read head you receive a telegram every few seconds that
contains the meter reading and, depending on the meter, the current power,
voltages, currents and more.

Tested against real telegrams from DZG, EBZ, EMH, Holley and ISKRA meters.

## Installation

```elixir
def deps do
  [
    {:sml_ex, "~> 0.1.0"}
  ]
end
```

## Usage

### Reading values

```elixir
{:ok, bezug_wh, 30} = Sml.value(telegram, :bezug)
{:ok, leistung_w, 27} = Sml.value(telegram, :leistung)
```

The third element is the DLMS unit code (`30` = Wh, `27` = W, see
`Sml.Units`). The meter's scaler is applied: you get an integer when the
scaler is not negative and a float otherwise.

Keys can be

* an alias atom, e.g. `:bezug`/`:import` (1.8.0), `:einspeisung`/`:export`
  (2.8.0), `:leistung`/`:power` (16.7.0), `:spannung_l1`, `:strom_l1`,
  `:hersteller`, `:server_id` (see `Sml.Obis` for the full list)
* an OBIS string: `"1-0:1.8.0"`, `"1-0:1.8.0*255"` or just `"1.8.0"`
* an `%Sml.Obis{}` struct or the raw 6 byte OBIS binary

To read several values, decode the telegram once:

```elixir
{:ok, file} = Sml.decode(telegram)
{:ok, bezug, 30} = Sml.value(file, :bezug)
{:ok, einspeisung, 30} = Sml.value(file, :einspeisung)

{:ok, values} = Sml.values(file)
#=> %{#Sml.Obis<1-0:1.8.0*255> => {12345678.9, 30}, ...}
```

### Inspecting telegrams

`Sml.decode/2` returns plain structs you can pattern match on:

```elixir
{:ok, %Sml.File{messages: messages}} = Sml.decode(telegram)

for %Sml.Message{body: %Sml.Messages.GetListResponse{val_list: entries}} <- messages,
    %Sml.ListEntry{unit: 27} = entry <- entries do
  {to_string(entry.obis), Sml.ListEntry.scaled_value(entry)}
end
#=> [{"1-0:16.7.0*255", 345}]
```

Message types the library does not know are kept as `{:unknown, tag, terms}`,
and `Sml.Parser.parse_all/1` turns any SML bytes into plain Elixir terms.

### Reading from a serial port

Telegrams arrive in arbitrary chunks. `Sml.Transport.extract/1` returns all
complete telegrams in a buffer plus the rest to keep for the next read:

```elixir
def handle_info({:circuits_uart, _port, chunk}, %{buffer: buffer} = state) do
  {telegrams, buffer} = Sml.Transport.extract(buffer <> chunk)

  for telegram <- telegrams do
    with {:ok, watt, 27} <- Sml.value(telegram, :leistung) do
      IO.puts("current power: #{watt} W")
    end
  end

  {:noreply, %{state | buffer: buffer}}
end
```

### Checksums

By default the transport and every message checksum are verified. Both
CRC-16/X-25 (standard) and CRC-16/Kermit (used e.g. by some Holley meters) are
accepted. Use `crc: :x25` or `crc: :kermit` to accept only one, or `crc: false`
to skip verification:

```elixir
Sml.decode(telegram, crc: false)
```

## License

MIT
