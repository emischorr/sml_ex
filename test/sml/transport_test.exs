defmodule Sml.TransportTest do
  use ExUnit.Case, async: true

  alias Sml.{Builder, Transport}

  @start <<0x1B1B1B1B::32, 0x01010101::32>>

  describe "unwrap/2" do
    test "returns the payload without padding" do
      assert Transport.unwrap(Builder.frame(<<1, 2, 3, 4, 5>>)) == {:ok, <<1, 2, 3, 4, 5>>}
      assert Transport.unwrap(Builder.frame(<<1, 2, 3, 4>>)) == {:ok, <<1, 2, 3, 4>>}
    end

    test "unescapes escape sequences in the payload" do
      payload = <<1, 2, 3, 4, 0x1B, 0x1B, 0x1B, 0x1B, 5>>
      frame = Builder.frame(payload)

      assert byte_size(frame) == 8 + 12 + 4 + 8
      assert Transport.unwrap(frame) == {:ok, payload}
    end

    test "skips garbage before the start sequence" do
      assert Transport.unwrap(<<0xFF, 0x00, 0x1B>> <> Builder.frame("abc")) == {:ok, "abc"}
    end

    test "detects broken frames" do
      frame = Builder.frame("abcd")
      size = byte_size(frame)

      assert Transport.unwrap("no telegram") == {:error, :no_start_sequence}
      assert Transport.unwrap(binary_part(frame, 0, size - 3)) == {:error, :incomplete}
      assert Transport.unwrap(binary_part(frame, 0, 12)) == {:error, :incomplete}

      broken_crc = binary_part(frame, 0, size - 2) <> <<0, 0>>
      assert Transport.unwrap(broken_crc) == {:error, :invalid_crc}
      assert Transport.unwrap(broken_crc, crc: false) == {:ok, "abcd"}

      invalid_escape = @start <> <<0x1B1B1B1B::32, 9, 9, 9, 9>>
      assert Transport.unwrap(invalid_escape) == {:error, :invalid_escape}

      invalid_padding = @start <> <<0x1B1B1B1B::32, 0x1A, 3, 0, 0>>
      assert Transport.unwrap(invalid_padding, crc: false) == {:error, :invalid_padding}
    end
  end

  describe "extract/1" do
    test "splits a stream into telegrams" do
      a = Builder.frame("first")
      b = Builder.frame(<<0x1B1B1B1B::32, "second">>)

      assert Transport.extract(<<0xFF, 0xFE>> <> a <> <<0, 0, 0>> <> b <> binary_part(a, 0, 10)) ==
               {[a, b], binary_part(a, 0, 10)}
    end

    test "works with arbitrary chunks" do
      telegrams = [Builder.frame("one"), Builder.frame("two"), Builder.frame("three")]
      stream = IO.iodata_to_binary(telegrams)

      {found, rest} =
        for <<byte <- stream>>, reduce: {[], <<>>} do
          {found, buffer} ->
            {new, buffer} = Transport.extract(buffer <> <<byte>>)
            {found ++ new, buffer}
        end

      assert found == telegrams
      assert rest == ""
    end

    test "keeps a partial start sequence" do
      assert Transport.extract(<<0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0x1B, 0x1B, 0x1B, 0x1B, 0x01>>) ==
               {[], <<0xDD, 0xEE, 0x1B, 0x1B, 0x1B, 0x1B, 0x01>>}
    end

    test "drops frames interrupted by a new start sequence" do
      complete = Builder.frame("complete")
      interrupted = @start <> "abcd"

      assert Transport.extract(interrupted <> complete) == {[complete], ""}
    end

    test "drops frames with invalid escape sequences" do
      complete = Builder.frame("complete")
      broken = @start <> <<0x1B1B1B1B::32, 9, 9, 9, 9>>

      assert Transport.extract(broken <> complete) == {[complete], ""}
    end
  end
end
