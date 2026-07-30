--
-- InfiniteBaleConsumables
--
-- Netz, Garn und Wickelfolie werden nicht mehr verbraucht.
--
-- Greift ueber drei Hooks in die globale Consumable-Spezialisierung ein.
-- Die Hooks werden beim Laden des Mods gesetzt; gebunden werden sie erst
-- spaeter in TypeManager:finalizeTypes(), daher gelten sie automatisch fuer
-- jeden Fahrzeugtyp mit Consumable-Spezialisierung -- Vanilla wie Mod-Geraet.
--
-- @author  LazyChilla
-- @version 1.0.0.0
--

InfiniteBaleConsumables = {}
InfiniteBaleConsumables.VERSION = "1.0.0.0"
InfiniteBaleConsumables.MOD_NAME = g_currentModName

---Laufzeit-Schalter. Nur fuer die aktuelle Sitzung, wird NICHT gespeichert --
-- nach einem Spielneustart ist der Mod wieder aktiv. Umschaltbar per
-- Konsolenbefehl `ibcToggle`, gedacht zum Gegentesten.
InfiniteBaleConsumables.enabled = true


---Prueft, ob ein Consumable-Typ von diesem Mod behandelt wird.
-- Verglichen wird gegen die Giants-Konstanten, nicht gegen fest verdrahtete
-- Strings -- so bleibt der Mod auch dann korrekt, wenn Giants die internen
-- Namen aendert.
-- @param string typeName Name des Consumable-Typs
-- @return boolean isHandled true, wenn der Typ nicht verbraucht werden soll
function InfiniteBaleConsumables.isHandledType(typeName)
    if typeName == nil or not InfiniteBaleConsumables.enabled then
        return false
    end

    if Baler ~= nil then
        if typeName == Baler.CONSUMABLE_TYPE_NAME_ROUND then
            return true
        end

        if typeName == Baler.CONSUMABLE_TYPE_NAME_SQUARE then
            return true
        end
    end

    if BaleWrapper ~= nil then
        if typeName == BaleWrapper.CONSUMABLE_TYPE_NAME then
            return true
        end
    end

    return false
end


---Hook 1: Verbrauch unterbinden.
-- Negative Deltas werden auf 0 gesetzt und trotzdem durchgereicht, damit die
-- Original-Funktion Meshes, Shader-Parameter und Animationen weiterhin
-- aktualisiert. Positives Nachfuellen von Hand bleibt unveraendert moeglich.
function InfiniteBaleConsumables.updateConsumable(self, superFunc, typeName, delta, consumingInProgress, fillConsumingSlots)
    if delta ~= nil and delta < 0 and InfiniteBaleConsumables.isHandledType(typeName) then
        delta = 0
    end

    return superFunc(self, typeName, delta, consumingInProgress, fillConsumingSlots)
end


---Hook 2: Verfuegbarkeit erzwingen.
-- Ohne diesen Hook wuerde eine leer gekaufte Presse (Shop-Konfiguration
-- "Leer") nie zu arbeiten anfangen, weil Baler:getIsWorkAreaActive() den
-- Fuellstand des laufenden Slots prueft.
function InfiniteBaleConsumables.getConsumableIsAvailable(self, superFunc, typeName)
    if InfiniteBaleConsumables.isHandledType(typeName) then
        return true
    end

    return superFunc(self, typeName)
end


---Hook 3: Leer-Warnung unterdruecken.
function InfiniteBaleConsumables.getShowConsumableEmptyWarning(self, superFunc, typeName)
    if InfiniteBaleConsumables.isHandledType(typeName) then
        return false
    end

    return superFunc(self, typeName)
end


---Setzt die Hooks auf die globale Consumable-Spezialisierung.
function InfiniteBaleConsumables.install()
    if Consumable == nil then
        Logging.error("InfiniteBaleConsumables: Spezialisierung 'Consumable' nicht gefunden. Mod bleibt inaktiv.")
        return
    end

    if Consumable.updateConsumable ~= nil then
        Consumable.updateConsumable = Utils.overwrittenFunction(Consumable.updateConsumable, InfiniteBaleConsumables.updateConsumable)
    else
        Logging.error("InfiniteBaleConsumables: Consumable.updateConsumable nicht gefunden.")
    end

    if Consumable.getConsumableIsAvailable ~= nil then
        Consumable.getConsumableIsAvailable = Utils.overwrittenFunction(Consumable.getConsumableIsAvailable, InfiniteBaleConsumables.getConsumableIsAvailable)
    else
        Logging.error("InfiniteBaleConsumables: Consumable.getConsumableIsAvailable nicht gefunden.")
    end

    if Consumable.getShowConsumableEmptyWarning ~= nil then
        Consumable.getShowConsumableEmptyWarning = Utils.overwrittenFunction(Consumable.getShowConsumableEmptyWarning, InfiniteBaleConsumables.getShowConsumableEmptyWarning)
    else
        Logging.error("InfiniteBaleConsumables: Consumable.getShowConsumableEmptyWarning nicht gefunden.")
    end

    Logging.info("InfiniteBaleConsumables v%s aktiv: Netz, Garn und Wickelfolie werden nicht mehr verbraucht.", InfiniteBaleConsumables.VERSION)
end


---Liefert den internen Typnamen einer Giants-Konstante, oder nil.
-- Eigene Hilfsfunktion, damit `ibcStatus` und `isHandledType` dieselbe
-- Nachschlage-Logik nutzen und nicht auseinanderlaufen koennen.
-- @param table class Klasse (Baler / BaleWrapper), darf nil sein
-- @param string constName Name der Konstante innerhalb der Klasse
-- @return string typeName interner Name, oder nil wenn nicht vorhanden
function InfiniteBaleConsumables.getTypeName(class, constName)
    if class == nil then
        return nil
    end

    return class[constName]
end


---Konsolenbefehl `ibcStatus`: zeigt an, was der Mod erkannt hat.
-- Beantwortet ohne Ingame-Versuch die Frage, ob ein Verbrauchsstoff
-- (z.B. Wickelfolie) ueberhaupt gefunden wurde.
function InfiniteBaleConsumables:consoleStatus()
    local lines = {}

    table.insert(lines, string.format("InfiniteBaleConsumables v%s -- Zustand: %s",
        InfiniteBaleConsumables.VERSION,
        InfiniteBaleConsumables.enabled and "AKTIV (kein Verbrauch)" or "AUS (normaler Verbrauch)"))

    local entries = {
        { label = "Rundballen-Netz", class = Baler,       classLabel = "Baler",       const = "CONSUMABLE_TYPE_NAME_ROUND" },
        { label = "Quaderballen-Garn", class = Baler,     classLabel = "Baler",       const = "CONSUMABLE_TYPE_NAME_SQUARE" },
        { label = "Wickelfolie",     class = BaleWrapper, classLabel = "BaleWrapper", const = "CONSUMABLE_TYPE_NAME" },
    }

    for _, e in ipairs(entries) do
        local typeName = InfiniteBaleConsumables.getTypeName(e.class, e.const)
        if typeName ~= nil then
            table.insert(lines, string.format("  [ja]   %-20s -> %s.%s = \"%s\"",
                e.label, e.classLabel, e.const, tostring(typeName)))
        elseif e.class == nil then
            table.insert(lines, string.format("  [nein] %-20s -> Klasse %s nicht vorhanden",
                e.label, e.classLabel))
        else
            table.insert(lines, string.format("  [nein] %-20s -> %s.%s nicht vorhanden",
                e.label, e.classLabel, e.const))
        end
    end

    local hooks = {
        { name = "updateConsumable" },
        { name = "getConsumableIsAvailable" },
        { name = "getShowConsumableEmptyWarning" },
    }

    local hookState = {}
    for _, h in ipairs(hooks) do
        local present = Consumable ~= nil and Consumable[h.name] ~= nil
        table.insert(hookState, string.format("%s: %s", h.name, present and "ja" or "NEIN"))
    end
    table.insert(lines, "  Hooks -- " .. table.concat(hookState, ", "))

    table.insert(lines, "  Umschalten mit: ibcToggle")

    local text = table.concat(lines, "\n")
    print(text)

    return text
end


---Konsolenbefehl `ibcToggle`: schaltet den Mod fuer diese Sitzung an/aus.
-- Bewusst NICHT persistent -- nach einem Spielneustart ist der Mod wieder
-- aktiv. Gedacht zum Gegentesten (Fuellstand mit und ohne Mod vergleichen).
function InfiniteBaleConsumables:consoleToggle()
    InfiniteBaleConsumables.enabled = not InfiniteBaleConsumables.enabled

    local text
    if InfiniteBaleConsumables.enabled then
        text = "InfiniteBaleConsumables: AKTIV -- Netz, Garn und Folie werden nicht verbraucht."
    else
        text = "InfiniteBaleConsumables: AUS -- normaler Verbrauch, nur fuer diese Sitzung."
    end

    print(text)

    return text
end


---Registriert die Konsolenbefehle, sobald die Karte geladen ist.
function InfiniteBaleConsumables:loadMap(name)
    addConsoleCommand("ibcStatus", "Zeigt Zustand und erkannte Verbrauchsstoffe von InfiniteBaleConsumables", "consoleStatus", InfiniteBaleConsumables)
    addConsoleCommand("ibcToggle", "Schaltet InfiniteBaleConsumables fuer diese Sitzung an/aus", "consoleToggle", InfiniteBaleConsumables)
end


InfiniteBaleConsumables.install()
addModEventListener(InfiniteBaleConsumables)
