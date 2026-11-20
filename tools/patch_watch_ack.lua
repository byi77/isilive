-- Acknowledged patch watch findings (rule 262, tools/check_api_surface.lua).
-- A `changed` or `removed` row that was checked against the code and does
-- not affect isiLive is listed here with the exact detail text of the report
-- and the reason. It then shows as `acknowledged` and no longer keeps the
-- weekly issue open. A different detail (Blizzard changes it again) is a new
-- finding. Remove an entry once the change is live (the row disappears then).
return {
  -- 12.1.7 PTR (70986) inserts isCrossShard in the middle of the payload.
  -- The handler (logic/isiLive_event_handlers_queue.lua) reads no payload
  -- value, it only reacts to the event. Checked 2026-11-20. 12.1.7 goes live
  -- on 2026-12-02 (patch only, no new season); remove this entry after that.
  PARTY_INVITE_REQUEST = {
    detail = "payload `(name:cstring, isTank:bool, isHealer:bool, isDamage:bool, isNativeRealm:bool, "
      .. "allowMultipleRoles:bool, inviterGUID:WOWGUID, questSessionActive:bool)` -> `(name:cstring, "
      .. "isTank:bool, isHealer:bool, isDamage:bool, isNativeRealm:bool, isCrossShard:bool, "
      .. "allowMultipleRoles:bool, inviterGUID:WOWGUID, questSessionActive:bool)`",
    reason = "handler reads no payload value",
  },
}
