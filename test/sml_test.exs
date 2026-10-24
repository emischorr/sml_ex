defmodule SmlTest do
  use ExUnit.Case, async: true

  alias Sml.{Builder, Fixtures, ListEntry, Messages, Obis}

  doctest Sml

  setup do
    %{telegram: Builder.telegram()}
  end

  describe "value/2" do
    test "the README examples", %{telegram: telegram} do
      {:ok, bezug_wh, 30} = Sml.value(telegram, :bezug)
      {:ok, leistung_w, 27} = Sml.value(telegram, :leistung)

      assert bezug_wh == 12_345_678.9
      assert leistung_w == -345
    end

    test "accepts all key formats", %{telegram: telegram} do
      for key <- [
            :bezug,
            :import,
            "1-0:1.8.0",
            "1-0:1.8.0*255",
            "1.8.0",
            <<1, 0, 1, 8, 0, 255>>,
            Obis.parse!(:bezug)
          ] do
        assert Sml.value(telegram, key) == {:ok, 12_345_678.9, 30}, "key #{inspect(key)}"
      end
    end

    test "non-numeric values", %{telegram: telegram} do
      assert Sml.value(telegram, :hersteller) == {:ok, "EMH", nil}
    end

    test "works on decoded files", %{telegram: telegram} do
      file = Sml.decode!(telegram)
      assert Sml.value(file, :einspeisung) == {:ok, 500.0, 30}
    end

    test "errors", %{telegram: telegram} do
      assert Sml.value(telegram, :spannung_l1) == {:error, :not_found}
      assert Sml.value(telegram, "1-0:1.8.0*0") == {:error, :not_found}
      assert Sml.value(telegram, :unknown) == {:error, {:unknown_alias, :unknown}}
      assert Sml.value(telegram, "garbage") == {:error, :invalid_obis}

      assert Sml.value("not a telegram", :bezug) ==
               {:error, {:parse_error, {:expected_list, 0b110}, 0}}
    end

    test "prefers the current value (F = 255) over historic values" do
      telegram =
        Builder.telegram(
          entries: [
            Builder.entry(<<1, 0, 1, 8, 0, 96>>, 30, 0, {:uint, 4, 1}),
            Builder.entry(<<1, 0, 1, 8, 0, 255>>, 30, 0, {:uint, 4, 2})
          ]
        )

      assert Sml.value(telegram, :bezug) == {:ok, 2, 30}
      assert Sml.value(telegram, "1-0:1.8.0*96") == {:ok, 1, 30}
    end
  end

  test "get/2 returns the whole entry", %{telegram: telegram} do
    assert {:ok, %ListEntry{obis: %Obis{c: 16, d: 7}, unit: 27, scaler: 0, value: -345}} =
             Sml.get(telegram, :leistung)
  end

  test "entries/1 and values/1", %{telegram: telegram} do
    assert {:ok, entries} = Sml.entries(telegram)
    assert length(entries) == 4

    assert {:ok, values} = Sml.values(telegram)
    assert values[Obis.parse!("1-0:2.8.0*255")] == {500.0, 30}
    assert map_size(values) == 4
  end

  describe "decode/2" do
    test "returns the message structure for pattern matching", %{telegram: telegram} do
      assert {:ok, %Sml.File{messages: messages}} = Sml.decode(telegram)

      assert [
               %Sml.Message{body: %Messages.OpenResponse{req_file_id: "file"}},
               %Sml.Message{
                 body: %Messages.GetListResponse{
                   act_sensor_time: {:sec_index, 1234},
                   val_list: [_, _, _, _]
                 }
               },
               %Sml.Message{body: %Messages.CloseResponse{}}
             ] = messages

      powers =
        for %Sml.Message{body: %Messages.GetListResponse{val_list: entries}} <- messages,
            %ListEntry{unit: 27} = entry <- entries,
            do: {to_string(entry.obis), ListEntry.scaled_value(entry)}

      assert powers == [{"1-0:16.7.0*255", -345}]
    end

    test "decodes messages without transport framing" do
      bare = Builder.open_response("srv") <> Builder.close_response()
      assert {:ok, %Sml.File{messages: [_, _]}} = Sml.decode(bare)
    end

    test "handles escape sequences inside values" do
      server_id = <<0x1B, 0x1B, 0x1B, 0x1B, 0x1B, 0x1B, 0x1B, 0x1B, 0x1B, 0x1B>>
      telegram = Builder.telegram(server_id: server_id)

      assert {:ok, %Sml.File{messages: [%{body: %{server_id: ^server_id}} | _]}} =
               Sml.decode(telegram)
    end

    test "decode!/2 raises" do
      assert_raise Sml.DecodeError, ~r/no_start_sequence|parse_error/, fn ->
        Sml.decode!(<<0x76>>)
      end
    end
  end

  describe "real telegrams" do
    @expected %{
      "dzg" => [
        bezug: {:ok, 13_391_000, 30},
        einspeisung: {:ok, 0, 30},
        leistung: {:error, :not_found},
        hersteller: {:ok, "DZG", 0}
      ],
      "holley" => [
        bezug: {:ok, 4_499_896.2, 30},
        leistung: {:ok, 137, 27},
        spannung_l1: {:ok, 234.4, 35},
        strom_l2: {:ok, 0.78, 33},
        frequenz: {:ok, 50.0, 44},
        hersteller: {:ok, "HLY", nil}
      ],
      "holley_kermit" => [
        bezug: {:ok, 10_793_898.7, 30},
        einspeisung: {:ok, 13_609_890.0, 30},
        leistung: {:ok, 188, 27}
      ],
      "emh" => [
        bezug: {:ok, 3_132_363.6, 30},
        einspeisung: {:ok, 3_072_718.1, 30},
        leistung: {:ok, 927, 27},
        hersteller: {:ok, "EMH", nil}
      ],
      "emh_signature" => [{"1-0:1.17.0", {:ok, 4050.8, 30}}],
      "iskra" => [
        bezug: {:ok, 18_619_047.0, 30},
        leistung: {:ok, 130, 27},
        leistung_l1: {:ok, 113, 27},
        hersteller: {:ok, "ISK", nil}
      ],
      "iskra_bare" => [
        bezug: {:ok, 5_672_051.4, 30},
        einspeisung: {:ok, 5_422_024.5, 30},
        leistung: {:ok, 196, 27}
      ]
    }

    for {fixture, expectations} <- @expected do
      test "#{fixture}" do
        telegram = Fixtures.load(unquote(fixture))

        for {key, expected} <- unquote(Macro.escape(expectations)) do
          assert Sml.value(telegram, key) == expected, "#{inspect(key)}"
        end
      end
    end

    test "ISKRA public key with multi-byte TL" do
      assert {:ok, %ListEntry{value: key}} = Sml.get(Fixtures.load("iskra"), "129-129:199.130.5")
      assert byte_size(key) == 48
    end

    test "Holley with Kermit checksums" do
      telegram = Fixtures.load("holley_kermit")

      assert {:ok, _} = Sml.decode(telegram, crc: :kermit)
      assert Sml.decode(telegram, crc: :x25) == {:error, :invalid_crc}
    end

    test "anonymized EBZ telegram has wrong message checksums" do
      telegram = Fixtures.load("ebz_anonymized")

      assert Sml.decode(telegram) == {:error, :invalid_crc}
      assert {:ok, file} = Sml.decode(telegram, crc: false)
      assert Sml.value(file, :bezug) == {:ok, 450_091.89911, 30}
      assert Sml.value(file, :leistung_l3) == {:ok, 243.57, 27}
      assert Sml.value(file, :hersteller) == {:ok, "EBZ", nil}
    end
  end
end
