# Questie's party protocol, byte by byte (Questie 12.9.0)

Read from Questie 12.9.0 (the owner's zip, kept outside the repository) so BookFinder can talk to party members who
use Questie. This is a description of the wire format in our words; BookFinder's code that speaks it is its own
(`BookFinder/Comms/`).

## 1. Addon-message framing (AceComm's rules)

Every Questie message goes through AceComm-3.0 on the addon channel:

- A message of **255 bytes or less** is sent as it is, except that one whose **first byte is 1 to 9** gets a byte 4
  put in front (if that keeps it at 255 or less; otherwise it is sent split, below).
- A longer message is **split** into pieces of 254 bytes of text: the first piece starts with byte **1**, middle
  pieces with byte **2**, the last with byte **3**. The receiver joins the pieces per prefix + channel + sender.
- On receipt: a message starting with byte 1, 2 or 3 is a piece; byte 4 is the escape (drop it, the rest is the
  message); bytes 5 to 9 at the start are ignored; anything else is a whole message.
- The sender's name is shortened the game's way (`Ambiguate(sender, "none")`: the realm is dropped for players of
  the player's own realm).
- AceComm sends through ChatThrottleLib (a bandwidth queue: about 800 bytes a second, bursts of 4000), priorities
  "BULK", "NORMAL", "ALERT".

## 2. Prefix `questie`: Questie's own serializer

### 2.1 The value encoding (one byte says what follows)

| First byte | Value |
|---|---|
| 32 to 253 | the number (byte - 32): whole numbers 0 to 221 |
| 1, 18, 19 | nil |
| 2 / 3 | a 32-bit unsigned int / its negative |
| 4 / 5 | a 64-bit int / its negative (numbers over 2147483646) |
| 6 | a float: 32 bits, IEEE single precision layout |
| 7 | a string of up to 254 bytes: one length byte, then the bytes |
| 8 | a longer string: a 16-bit length, then the bytes |
| 9 | a string sent before in the same message: its 32-bit hash |
| 10 / 11 | a table of key/value pairs: count in 1 byte / 16 bits, then key, value, key, value... |
| 12 / 13 | a whole number 222 to 254 in one byte / its negative (negatives from 0 to 254) |
| 14 / 15 | a whole number below 65530 in 16 bits / its negative |
| 16 / 17 | false / true |
| 20 / 21 / 22 | an array: count in 1 byte / 16 bits / 32 bits, then the values in order |

- Numbers: whole numbers use the smallest form (0 to 221 inside the type byte; below 255 one byte; below 65530 two
  bytes; else four; over 2147483646 eight). A number with a fractional part above 0 is a float (6). 5.0 counts as
  whole (sent as 37).
- Multi-byte numbers are big-endian (high byte first).
- Strings: a string longer than 4 bytes that was already written in this message (as a key or a value, anywhere
  before) is written as type 9 + the hash of the string. Both sides keep the same table, adding each string right
  after it is written or read (a table key, then its value; an array's values in order). If two strings hash the
  same, only the first is kept. The hash: h = 5381; for each byte, h = band(31 * h + byte, 4294967295) (the game's
  own `bit.band`).
- Tables: a table whose keys are exactly 1..n is an array (20/21/22); any other is key/value (10/11). Pairs whose key
  or value is nil or **false** are left out of key/value tables (so a `false` never arrives: it reads as nil).
- A message is the packet written as the value of key 1 of a one-pair table: the bytes are 10, 1 (pair count),
  33 (the key 1), then the packet.

### 2.2 The byte streams (how bytes become message text)

- **"1short"** (every message except yells): each byte as it is, except **0** is written as byte **238**, **237**
  as 237, 1 and **238** as 237, 2. Reading reverses it.
- **"b89"** (yells only): each value byte e is written as a printable character: a level (e div 86) is changed when
  needed by writing "x" (level 0), "y" (1) or "z" (2); then (e mod 86) + 33, where 34 (") becomes 123, 39 (') 124 and
  92 (\) 125. Reading: x/y/z set the level; 123/124/125 mean 1/6/59; any other character c means level * 86 + c - 33.
  **Quirk**: in this stream Questie writes a string's characters raw (only the length byte is encoded) but reads them
  back encoded, so Questie cannot read the strings of its own yells: the keys come out wrong and Questie drops every
  yell it receives. BookFinder writes yells the way Questie does and reads their strings raw (correctly).

### 2.3 Packets

Every packet (except yells) is a key/value table: `ver` (the sender's Questie version, "12.9.0"), `msgVer` (5: the
protocol; a receiver drops packets whose whole number differs and says so once), `msgId`, then the message's own
fields. Yells have no `msgVer`.

**`ver` matters**: a Questie receiver compares it to its own, and if ours is newer prints "A Major patch for Questie
exists!" / "You have an outdated version of Questie!"; a `ver` that is not three numbers breaks its reading (the
packet is lost). It also decides the format of a reply to a quest-log request (major above 5: version 2 lists). So
BookFinder sends a low, three-number version.

| msgId | Name | Fields | Sent |
|---|---|---|---|
| 1 | Quest update | `quest` = { `id`, `objectives` = array of { `id`, `typ` (first letter of the objective type: m, i, o, r, e, l...), `fin` (true or absent), `ful`, `req` } } | party/raid/instance, NORMAL, when a quest is accepted or its progress changes |
| 2 | Quest removed | `id` | ALERT, when a quest leaves the log (handed in or abandoned) |
| 10 | Full quest list (v1) | `rawQuestList` = { [questId] = the `quest` table of msgId 1, ... } | in blocks under ~200 bytes serialized, one every 3 s (after a random 0-3 s), as the answer to 11 from a version 5 or lower |
| 11 | Ask for the quest list | (none) | when the player joins a group (party or raid has someone in it) |
| 12 | Full quest list (v2) | `[1]` = array: count, then per quest: questId, objective count, then per objective: id (0 if none), byte of the type letter, have, need | as 10, to a version above 5 |
| 13 | Yell progress (b89) | `[1]` = array: questId, objective count, class index (Druid 1, Hunter 2, Mage 3, Priest 4, Rogue 5, Shaman 6, Warlock 7, Warrior 8), then per objective: id, type byte, have, need | YELL, BULK, 2 s apart, solo or small group (4 or fewer), not in capital cities or battlegrounds, not in the first 8 s after loading |
| 14 | Quest update (v2) | `[1]` = the v2 list shape for one quest (no count) | (future use; read) |

- The objective `id` is the data's ID of what the objective needs (the creature, item or object), as in QuestieDB.
- Receiving: group channels are accepted only from party or raid members; the player's own messages are ignored.
  A remote player's quest is replaced whole by each update; an objective is finished when have equals need.
- Questie sends nothing to groups of more than 15 or in battlegrounds (except whispers).
- On leaving a group every group player's data is dropped; yelled ("nearby") players are kept for 4 minutes, the
  3 most recent shown.

## 3. Prefix `QuestieV1`: which quests a party member wants shown

- The payload is a table { [questId] = true | false } for every quest in the sender's log: true when the quest is
  tracked and not hidden, false otherwise. It tells party members whether to draw that player's objectives.
- Encoding: the game's `C_EncodingUtil.SerializeCBOR`, then `C_EncodingUtil.CompressString(cbor, Deflate, Default)`,
  then LibDeflate's addon-channel escape: byte **0** becomes bytes **1, 2** and byte **1** becomes **1, 3** (every
  other byte unchanged). The result is at most 762 bytes (3 AceComm pieces), else it is not sent.
- Sent (a random 0-2 s later, the latest wins) to PARTY / RAID / INSTANCE_CHAT, only in groups of 5 or fewer: on
  joining a group, on a roster change, on accepting, handing in, abandoning, hiding or unhiding a quest, and with the
  answer to a quest-list request.
- Received only from party or raid members; a snapshot with more entries than the quest log can hold, or any key that
  is not a positive whole number or value that is not a boolean, is dropped. A player who never sent one shows all.

## 4. Chat links

`|Hquestie:<questID>:<senderGUID>|h[<text>]|h`: Questie turns quest names in chat into these; clicking shows the quest's
tooltip.
