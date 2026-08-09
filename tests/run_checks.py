from __future__ import annotations

import re
import sys
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "GuildHubClassic"
TEST_DEPS = ROOT / "tools" / "test-deps"
sys.path.insert(0, str(TEST_DEPS))

from lupa import LuaRuntime  # type: ignore  # noqa: E402


def check_lua_syntax() -> int:
    lua = LuaRuntime(unpack_returned_tuples=True)
    compile_lua = lua.eval(
        "function(source) local chunk, err = load(source, '@syntax-check'); "
        "return chunk ~= nil, err end"
    )
    checked = 0
    for path in sorted(ADDON.rglob("*.lua")):
        if "Libs" in path.parts:
            continue
        source = path.read_text(encoding="utf-8")
        ok, error = compile_lua(source)
        assert ok, f"Lua syntax error in {path.relative_to(ROOT)}: {error}"
        checked += 1
    assert checked >= 20, f"Expected at least 20 first-party Lua files, got {checked}"
    return checked


def check_toc() -> int:
    toc = ADDON / "GuildHubClassic.toc"
    references = []
    for raw in toc.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("##"):
            continue
        references.append(line)
        target = ADDON / Path(line.replace("\\", "/"))
        assert target.is_file(), f"TOC references missing file: {line}"
    assert references[-1] == "Core\\Addon.lua"
    return len(references)


def locale_keys(path: Path) -> set[str]:
    source = path.read_text(encoding="utf-8")
    return set(re.findall(r"^\s+([A-Z][A-Z0-9_]+)\s*=", source, re.MULTILINE))


def check_locales() -> int:
    locale_dir = ADDON / "Locales"
    locales = {
        name: locale_keys(locale_dir / f"{name}.lua")
        for name in ("enUS", "ruRU", "ukUA")
    }
    assert len(locales["enUS"]) >= 100
    for name, keys in locales.items():
        missing = locales["enUS"] - keys
        extra = keys - locales["enUS"]
        assert not missing, f"{name} missing locale keys: {sorted(missing)}"
        assert not extra, f"{name} has extra locale keys: {sorted(extra)}"
    return len(locales["enUS"])


def check_api_boundary() -> int:
    forbidden = re.compile(
        r"\b(?:C_ChatInfo|C_Container|C_PartyInfo|GetGuildRosterInfo|"
        r"GetNumGuildMembers|Unit(?:Name|Level|Class|FullName)|GetServerTime|"
        r"InviteUnit|GuildRoster)\b"
    )
    checked = 0
    paths = list((ADDON / "Modules").glob("*.lua"))
    paths += [
        path
        for path in (ADDON / "Core").glob("*.lua")
        if path.name not in {"GameAPI.lua", "Bootstrap.lua", "Addon.lua"}
    ]
    for path in paths:
        source = path.read_text(encoding="utf-8")
        match = forbidden.search(source)
        assert not match, (
            f"Direct WoW API call {match.group(0)!r} outside GameAPI adapter "
            f"in {path.relative_to(ROOT)}"
        )
        checked += 1
    return checked


def load_first_party(lua: LuaRuntime):
    loader = lua.eval(
        """
        function(source, addonName, namespace)
            local chunk, err = load(source, "@test-module")
            if not chunk then error(err) end
            return chunk(addonName, namespace)
        end
        """
    )
    ns = lua.table()

    def load(relative: str) -> None:
        source = (ADDON / relative).read_text(encoding="utf-8")
        loader(source, "GuildHubClassic", ns)

    load("Core/Bootstrap.lua")
    lua.execute(
        """
        local ns = ...
        TEST_NOW = 2000000000
        TEST_RANK = 0
        ns.GameAPI = {}
        function ns.GameAPI:Now() TEST_NOW = TEST_NOW + 1 return TEST_NOW end
        function ns.GameAPI:GetPlayerName() return "Player-Realm" end
        function ns.GameAPI:GetPlayerLevel() return 60 end
        function ns.GameAPI:GetPlayerClass() return "Warrior", "WARRIOR" end
        function ns.GameAPI:GetGuildKey() return "Realm:Alliance:Guild" end
        function ns.GameAPI:GetGuildRankIndex(name)
            if name == "Player-Realm" then return TEST_RANK, "Test" end
            if name == "Officer-Realm" then return 1, "Officer" end
            return 3, "Member"
        end
        function ns.GameAPI:NormalizeCharacterName(name)
            if string.find(name, "-", 1, true) then return name end
            return name .. "-Realm"
        end
        function ns.GameAPI:IsInGuild() return true end
        function ns.GameAPI:ScanCurrentBank()
            return { ["14047"] = { itemID = 14047, name = "Runecloth", count = 20, quality = 1 } }
        end
        function ns.GameAPI:Invite() return true end
        function ns:L(key) return key end
        """,
        ns,
    )
    for relative in (
        "Core/Database.lua",
        "Core/Permissions.lua",
        "Core/Validation.lua",
        "Core/Store.lua",
        "Modules/Profiles.lua",
        "Modules/News.lua",
        "Modules/Requests.lua",
        "Modules/Groups.lua",
        "Modules/Tasks.lua",
        "Modules/Bank.lua",
    ):
        load(relative)
    lua.execute(
        """
        local ns = ...
        ns.Comm = {
            BroadcastOperation = function() end,
            BroadcastConfig = function() end,
        }
        """,
        ns,
    )
    return ns


def check_behaviour() -> int:
    lua = LuaRuntime(unpack_returned_tuples=True)
    ns = load_first_party(lua)
    lua.execute(
        """
        local ns = ...
        assert(ns.Database:Initialize())
        local guild = ns.Database:GetGuild()
        assert(guild.config.requestMinLevel == 6)
        assert(guild.config.maxActiveRequests == 5)
        assert(guild.config.maxActiveGroups == 3)

        local invalid, invalidReason = ns.modules.Requests:Create({
            title = "Invalid duration", description = "Test", category = "help", durationHours = 2,
        })
        assert(invalid == nil and invalidReason == "invalid-request")

        for index = 1, 5 do
            local request = ns.modules.Requests:Create({
                title = "Request " .. index,
                description = "Need help",
                category = "help",
                durationHours = 24,
            })
            assert(request and request.status == "active")
        end
        local overflow, overflowReason = ns.modules.Requests:Create({
            title = "Overflow", description = "Need help", category = "help", durationHours = 24,
        })
        assert(overflow == nil and overflowReason == "request-limit")

        for index = 1, 3 do
            local group = ns.modules.Groups:Create({
                title = "Group " .. index,
                description = "Dungeon group",
                size = 5,
                startAt = ns.GameAPI:Now() + 3600,
            })
            assert(group and group.expiresAt > group.startAt)
        end
        local fourth, fourthReason = ns.modules.Groups:Create({
            title = "Fourth", description = "No room", size = 5,
        })
        assert(fourth == nil and fourthReason == "group-limit")

        local task = ns.modules.Tasks:Create({
            title = "Potions", description = "Collect potions", goal = 60, respect = 10,
        })
        assert(task)
        local contribution = ns.modules.Tasks:Report(task.id, { amount = 12, comment = "Delivered" })
        assert(contribution and contribution.status == "pending")
        local reported, confirmed = ns.modules.Tasks:GetProgress(task.id)
        assert(reported == 12 and confirmed == 0)
        assert(ns.modules.Tasks:Confirm(contribution.id, true))
        reported, confirmed = ns.modules.Tasks:GetProgress(task.id)
        assert(reported == 12 and confirmed == 12)
        local respect, history = ns.modules.Tasks:GetRespect("Player-Realm")
        assert(respect == 10 and #history == 1)

        local tag = ns.modules.Bank:SetTags(14047, { "Molten Core", "Materials" }, "Raid stock")
        assert(tag and #tag.tags == 2)
        local view = ns.modules.Bank:CreateView("Molten Core", { tag = "Molten Core" })
        assert(view and view.filters.tag == "Molten Core")

        local firstRequest = ns.modules.Requests:List(false)[1]
        firstRequest.expiresAt = ns.GameAPI:Now() - 1
        ns.Store:RunMaintenance()
        assert(firstRequest.status == "archived")

        TEST_RANK = 3
        local forbidden, reason = ns.modules.Tasks:Create({
            title = "Forbidden", description = "Member task", goal = 1, respect = 0,
        })
        assert(forbidden == nil and reason == "permission")

        TEST_RANK = 0
        for memberIndex = 1, 200 do
            local actor = "Load" .. memberIndex .. "-Realm"
            for requestIndex = 1, 5 do
                ns.Store:Create("requests", {
                    title = "Load request", description = "Load", category = "help",
                    expiresAt = ns.GameAPI:Now() + 86400,
                }, { actor = actor })
            end
            for groupIndex = 1, 3 do
                ns.Store:Create("groups", {
                    title = "Load group", description = "Load", size = 5,
                    startAt = ns.GameAPI:Now() + 3600,
                }, { actor = actor })
            end
        end
        assert(#ns.Store:List("requests", false) == 1004)
        assert(#ns.Store:List("groups", false) == 603)
        local bankItems = {}
        for itemIndex = 1, 2000 do
            bankItems[tostring(itemIndex)] = {
                itemID = itemIndex, name = "Item " .. itemIndex, count = itemIndex, quality = 1,
            }
        end
        assert(ns.Store:Create("bankSnapshots", {
            items = bankItems, itemTypeCount = 2000, scannedAt = ns.GameAPI:Now(),
        }, { actor = "LoadBank-Realm" }))
        assert(#ns.modules.Bank:ListItems() == 2000)
        """,
        ns,
    )
    return 19


def check_vendor_runtime() -> int:
    lua = LuaRuntime(unpack_returned_tuples=True)
    for relative in (
        "Libs/LibStub/LibStub.lua",
        "Libs/LibSerialize/LibSerialize.lua",
        "Libs/LibDeflate/LibDeflate.lua",
    ):
        source = (ADDON / relative).read_text(encoding="utf-8")
        lua.execute(source)
    lua.execute(
        """
        local serializer = LibStub("LibSerialize")
        local deflate = LibStub("LibDeflate")
        local source = { version = 1, text = "Guild Hub", values = {} }
        for index = 1, 200 do source.values[index] = { id = index, count = index * 3 } end
        local serialized = serializer:Serialize(source)
        local compressed = assert(deflate:CompressDeflate(serialized))
        local encoded = assert(deflate:EncodeForWoWAddonChannel(compressed))
        local decoded = assert(deflate:DecodeForWoWAddonChannel(encoded))
        local restored = assert(deflate:DecompressDeflate(decoded))
        local ok, result = serializer:Deserialize(restored)
        assert(ok and result.version == 1 and #result.values == 200)
        """
    )
    for name in (
        "Ace3-LICENSE.txt",
        "LibSerialize-LICENSE.txt",
        "LibDeflate-LICENSE.txt",
    ):
        assert (ADDON / "Libs" / "Licenses" / name).is_file()
    return 4


def main() -> None:
    results = {
        "first-party Lua files parsed": check_lua_syntax(),
        "TOC file references checked": check_toc(),
        "localization keys matched": check_locales(),
        "API-boundary files checked": check_api_boundary(),
        "behaviour assertions passed": check_behaviour(),
        "vendor runtime and licenses checked": check_vendor_runtime(),
    }
    for label, count in results.items():
        print(f"PASS: {label}: {count}")


if __name__ == "__main__":
    main()
