--[[
	Arena
	-----
	Die Spielsitzung EINES Spielers: sein Level, seine Bauteile, sein Test.

	Warum bekommt jeder Spieler eine eigene Arena?
	Weil jeder sein eigenes Level waehlen darf. Zwei Spieler koennten also
	gleichzeitig an voellig verschiedenen Bruecken bauen. Die Arenen liegen
	senkrecht uebereinander gestapelt (siehe Config.Arena) und stoeren sich
	dadurch nicht - die Kamera schaut waagerecht und sieht immer nur eine.

	Diese Klasse fasst alles zusammen, was zu einer Sitzung gehoert, und
	haelt die Phase fest:
	  "Build"  - es wird gebaut
	  "Test"   - der Belastungstest laeuft
	  "Result" - der Test ist vorbei, das Ergebnis steht fest
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BridgeLab")
local Config = require(Shared.Config)

local LevelBuilder = require(script.Parent.LevelBuilder)
local Structure = require(script.Parent.Structure)
local ForceEngine = require(script.Parent.ForceEngine)
local TestRun = require(script.Parent.TestRun)

local Arena = {}
Arena.__index = Arena

--------------------------------------------------------------------------------
-- Aufbau und Abbau
--------------------------------------------------------------------------------

function Arena.new(player: Player, level, slotIndex: number, parentFolder: Instance)
	local self = setmetatable({}, Arena)

	self.player = player
	self.level = level
	self.slotIndex = slotIndex

	-- Jede Arena sitzt um ein Vielfaches von spacingY hoeher als die erste.
	self.origin = Vector3.new(0, slotIndex * Config.Arena.spacingY, 0)

	self.folders = LevelBuilder.build(level, self.origin, parentFolder)
	self.folders.root.Name = string.format("Arena_%d_%s", slotIndex, player.Name)
	-- Damit der Client SEINE Arena zweifelsfrei wiederfindet. Ueber den Namen
	-- zu suchen waere unsicher, Namen koennen sich aehneln.
	self.folders.root:SetAttribute("OwnerUserId", player.UserId)

	self.structure = Structure.new(level, self.origin, self.folders)
	self.forceEngine = ForceEngine.new(level, self.structure)
	self.testRun = TestRun.new(level, self.origin, self.folders, self.structure, self.forceEngine)

	self.phase = "Build"
	self.stable = true
	self.unstableNode = nil
	self.message = ""
	self.result = nil
	self.testProgress = nil
	self.unlockedHints = {}

	-- Vom Spieler am Tacho eingestellte Fahrgeschwindigkeit.
	self.testSpeed = Config.Test.defaultSpeed

	--[[
		Muss neu gerechnet werden?
		Im Baumodus sind alle Knoten verankert - es bewegt sich nichts, und
		das Ergebnis kann sich nur aendern, wenn ein Bauteil dazukommt oder
		verschwindet. Staendiges Nachrechnen waere reine Verschwendung,
		besonders bei sechzehn Arenen gleichzeitig.
	]]
	self.needsAnalysis = false

	-- Wird von aussen gesetzt: "der Zustand hat sich geaendert, bitte senden".
	self.onStateChanged = nil

	return self
end

function Arena:destroy()
	if self.testRun:isRunning() then
		self.testRun:stop()
	end
	self.structure:clear()
	if self.folders.root then
		self.folders.root:Destroy()
	end
end

--------------------------------------------------------------------------------
-- Zustand fuer den Client
--------------------------------------------------------------------------------

function Arena:buildState()
	return {
		levelId = self.level.id,
		levelName = self.level.displayName,
		difficulty = self.level.difficulty,

		phase = self.phase,
		budgetTotal = self.level.budget,
		budgetUsed = self.structure:usedBudget(),
		memberCount = #self.structure.members,

		stable = self.stable,
		unstableNode = self.unstableNode,
		message = self.message,
		result = self.result,
		testProgress = self.testProgress,

		allowedParts = self.level.allowedParts,
		testSpeed = self.testSpeed,
		vehicleCount = #self.level.vehicles,
		deckCount = #self.level.decks,
		unlockedHints = self.unlockedHints,
		hintTotal = #self.level.hints,
		freeHints = self.level.freeHints,

		-- Die Kamera des Clients muss wissen, wo seine Arena steht.
		originY = self.origin.Y,
		bounds = self.level.bounds,
		deckY = self.level.deckY,
	}
end

function Arena:notify()
	if self.onStateChanged then
		self.onStateChanged(self)
	end
end

--------------------------------------------------------------------------------
-- Baumodus: Kraefte regelmaessig nachrechnen
--------------------------------------------------------------------------------

--[[
	Wird jeden Frame vom Hauptskript aufgerufen, rechnet aber nur dann wirklich,
	wenn sich seit dem letzten Mal etwas geaendert hat.
]]
function Arena:tick(dt: number)
	--[[
		Waehrend des Tests rechnet TestRun selbst - und zwar mit den Lasten der
		Fahrzeuge. Hier waere das doppelt gemoppelt.
	]]
	if self.phase == "Test" then
		return
	end

	--[[
		Ausserhalb des Tests sind alle Knoten verankert: es bewegt sich nichts.
		Das Ergebnis kann sich also nur aendern, wenn ein Bauteil dazukommt
		oder verschwindet. Deshalb wird nur auf Anforderung gerechnet - bei
		sechzehn Arenen spart das eine Menge Rechenzeit.
	]]
	if not self.needsAnalysis then
		return
	end
	self.needsAnalysis = false

	self:updateAnalysis()
end

-- Kraefte neu bestimmen, einfaerben und bei Aenderung den Client benachrichtigen.
function Arena:updateAnalysis()
	local result = self.forceEngine:evaluate(nil)
	-- Im Baumodus behalten die Bauteile ihre eigene Farbe (Stahl, Beton, Seil).
	self.forceEngine:applyColors(false)

	local stable = not result.unstable
	if stable ~= self.stable or result.worstNodeIndex ~= self.unstableNode then
		self.stable = stable
		self.unstableNode = result.worstNodeIndex
		self:notify()
	end
end

--------------------------------------------------------------------------------
-- Aktionen des Spielers
--------------------------------------------------------------------------------

-- Rueckgabe: erfolgreich (boolean), Meldung fuer den Spieler (string)
function Arena:placeMember(kind: string, a: number, b: number): (boolean, string)
	if self.phase ~= "Build" then
		return false, "Waehrend des Tests laesst sich nicht bauen."
	end

	local allowed, reason = self.structure:canPlace(kind, a, b)
	if not allowed then
		return false, reason
	end

	self.structure:place(kind, a, b)
	self.message = ""
	self:updateAnalysis()
	self:notify()
	return true, ""
end

function Arena:removeMember(memberId: number): (boolean, string)
	if self.phase ~= "Build" then
		return false, "Waehrend des Tests laesst sich nichts entfernen."
	end
	if not self.structure:remove(memberId) then
		return false, ""
	end
	self:updateAnalysis()
	self:notify()
	return true, ""
end

--[[
	Startet den Belastungstest.
	onComplete(success, reason) wird aufgerufen, wenn der Test vorbei ist -
	das Hauptskript nutzt das, um den Levelfortschritt zu speichern.
]]
function Arena:startTest(speed: number, onComplete): (boolean, string)
	if self.phase ~= "Build" then
		return false, "Der Test laeuft schon."
	end
	if #self.structure.members == 0 then
		return false, "Erst bauen, dann testen."
	end

	self.testSpeed = math.clamp(speed, Config.Test.minSpeed, Config.Test.maxSpeed)

	self.phase = "Test"
	self.result = nil
	self.message = "Test laeuft ..."
	self.testProgress = {
		countdown = Config.Test.countdownSeconds,
		elapsed = 0,
		maxUtilisation = 0,
		speed = self.testSpeed,
		vehiclesDone = 0,
		vehicleCount = #self.level.vehicles,
	}
	self:notify()

	self.testRun:start(self.testSpeed, function(progress)
		-- Fortschritt waehrend der Fahrt (Countdown, Zeit, hoechste Auslastung)
		self.testProgress = progress
		self:notify()
	end, function(success, reason)
		self.phase = "Result"
		self.result = { success = success, reason = reason }
		self.message = reason
		self.testProgress = nil
		-- Einmal nachrechnen, damit die Bauteile wieder ihre eigene Farbe
		-- bekommen statt der Auslastungsfarbe aus dem Test.
		self.needsAnalysis = true
		self:notify()

		if onComplete then
			onComplete(success, reason)
		end
	end)

	return true, ""
end

--[[
	Geschwindigkeit am Tacho veraendern. Erlaubt ist das jederzeit - auch
	mitten in der Fahrt. Der Server begrenzt den Wert selbst, damit ein
	veraenderter Client kein unsinniges Tempo durchsetzen kann.
]]
function Arena:setTestSpeed(speed: number)
	self.testSpeed = math.clamp(speed, Config.Test.minSpeed, Config.Test.maxSpeed)
	if self.testRun:isRunning() then
		self.testRun:setSpeed(self.testSpeed)
	end
	self:notify()
end

-- Konstruktion in den Ausgangszustand bringen. Der Bauplan bleibt erhalten.
function Arena:reset()
	if self.testRun:isRunning() then
		self.testRun:stop()
	end
	self.structure:rebuild()
	self.phase = "Build"
	self.result = nil
	self.testProgress = nil
	self.message = ""
	self.needsAnalysis = true
	self:updateAnalysis()
	self:notify()
end

-- Alles abreissen und mit leerem Bauplan neu anfangen.
function Arena:clearBuild()
	if self.testRun:isRunning() then
		self.testRun:stop()
	end
	self.structure:clear()
	self.phase = "Build"
	self.result = nil
	self.testProgress = nil
	self.message = ""
	self.stable = true
	self.unstableNode = nil
	self:notify()
end

--------------------------------------------------------------------------------
-- Tipps
--------------------------------------------------------------------------------

-- Merkt sich einen aufgedeckten Tipp, damit er nach einem Neuladen wieder da ist.
function Arena:addUnlockedHint(text: string)
	table.insert(self.unlockedHints, text)
end

function Arena:setUnlockedHints(list: { string })
	self.unlockedHints = list
end

return Arena
