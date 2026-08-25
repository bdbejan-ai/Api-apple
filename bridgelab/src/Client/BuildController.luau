--[[
	BuildController
	---------------
	Die Bau-Interaktion auf dem Client.

	WIE DAS ANKLICKEN FUNKTIONIERT
	Statt jedem Ankerpunkt einen ClickDetector zu geben, wird der Strahl unter
	dem Mauszeiger (mouse.UnitRay) genommen und geprueft, welcher Ankerpunkt
	diesem Strahl am naechsten liegt. Das ist unabhaengig von der Kameraposition
	und funktioniert auch, wenn ein Bauteil den Punkt halb verdeckt.

	ABLAUF
	  1. Bauteiltyp im Menue waehlen.
	  2. Ersten Ankerpunkt anklicken  -> wird gemerkt.
	  3. Zweiten Ankerpunkt anklicken -> Wunsch geht an den Server.
	Der Server entscheidet, ob das Bauteil wirklich entsteht.

	Rechtsklick (oder Linksklick im Entfernen-Modus) auf ein Bauteil schickt
	den Wunsch, es wieder zu entfernen.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BridgeLab")
local Config = require(Shared.Config)

local BuildController = {}
BuildController.__index = BuildController

-- Wie weit der Mauszeiger vom Ankerpunkt entfernt sein darf (in Studs,
-- gemessen quer zum Sichtstrahl). Waechst mit der Entfernung mit, damit weit
-- entfernte Punkte nicht unmoeglich zu treffen sind.
local function pickRadius(distance: number): number
	return math.clamp(distance * 0.03, 1.5, 6)
end

--------------------------------------------------------------------------------

function BuildController.new(remotes, gui)
	local self = setmetatable({}, BuildController)

	self.remotes = remotes
	self.gui = gui
	self.selectedKind = "Beam"
	self.removeMode = false
	self.firstSnap = nil
	self.phase = "Build"

	self.player = Players.LocalPlayer
	self.mouse = self.player:GetMouse()

	local bridgeLab = workspace:WaitForChild("BridgeLab")
	self.snapFolder = bridgeLab:WaitForChild("SnapPoints")
	self.memberFolder = bridgeLab:WaitForChild("Members")

	-- Markierung fuer den Ankerpunkt unter dem Mauszeiger.
	self.hoverMarker = Instance.new("Part")
	self.hoverMarker.Name = "HoverMarker"
	self.hoverMarker.Shape = Enum.PartType.Ball
	self.hoverMarker.Size = Vector3.new(2.2, 2.2, 2.2)
	self.hoverMarker.Anchored = true
	self.hoverMarker.CanCollide = false
	self.hoverMarker.CanQuery = false
	self.hoverMarker.CanTouch = false
	self.hoverMarker.Material = Enum.Material.Neon
	self.hoverMarker.Color = Color3.fromRGB(255, 255, 255)
	self.hoverMarker.Transparency = 0.5
	self.hoverMarker.Parent = workspace

	-- Markierung fuer den bereits gewaehlten ersten Ankerpunkt.
	self.startMarker = self.hoverMarker:Clone()
	self.startMarker.Name = "StartMarker"
	self.startMarker.Color = Color3.fromRGB(120, 220, 255)
	self.startMarker.Transparency = 1
	self.startMarker.Parent = workspace

	-- Markierung fuer die Stelle, an der die Konstruktion nicht ausgesteift ist.
	self.weakMarker = self.hoverMarker:Clone()
	self.weakMarker.Name = "WeakSpotMarker"
	self.weakMarker.Size = Vector3.new(3, 3, 3)
	self.weakMarker.Color = Color3.fromRGB(255, 90, 70)
	self.weakMarker.Transparency = 1
	self.weakMarker.Parent = workspace

	-- Vorschau-Linie zwischen erstem und aktuell anvisiertem Ankerpunkt.
	self.preview = Instance.new("Part")
	self.preview.Name = "PlacementPreview"
	self.preview.Anchored = true
	self.preview.CanCollide = false
	self.preview.CanQuery = false
	self.preview.CanTouch = false
	self.preview.Material = Enum.Material.Neon
	self.preview.Transparency = 1
	self.preview.Size = Vector3.new(0.4, 0.4, 1)
	self.preview.Parent = workspace

	self.raycastParams = RaycastParams.new()
	self.raycastParams.FilterType = Enum.RaycastFilterType.Include
	self.raycastParams.FilterDescendantsInstances = { self.memberFolder }

	self:connectInput()

	self.renderConnection = RunService.RenderStepped:Connect(function()
		self:updateHover()
	end)

	return self
end

--------------------------------------------------------------------------------
-- Ankerpunkt unter dem Mauszeiger finden
--------------------------------------------------------------------------------

function BuildController:findSnapUnderMouse(): (number?, Vector3?)
	local ray = self.mouse.UnitRay
	local origin = ray.Origin
	local direction = ray.Direction.Unit

	local bestIndex, bestPosition = nil, nil
	local bestScore = math.huge

	for _, marker in self.snapFolder:GetChildren() do
		local index = marker:GetAttribute("SnapIndex")
		if not index then
			continue
		end

		local toPoint = marker.Position - origin
		local along = toPoint:Dot(direction)
		if along < 1 or along > 400 then
			continue
		end

		-- Abstand des Ankerpunkts vom Sichtstrahl.
		local offset = (toPoint - direction * along).Magnitude
		if offset <= pickRadius(along) and offset < bestScore then
			bestScore = offset
			bestIndex = index
			bestPosition = marker.Position
		end
	end

	return bestIndex, bestPosition
end

function BuildController:findMemberUnderMouse(): number?
	local ray = self.mouse.UnitRay
	local hit = workspace:Raycast(ray.Origin, ray.Direction.Unit * 400, self.raycastParams)
	if hit and hit.Instance then
		return hit.Instance:GetAttribute("MemberId")
	end
	return nil
end

--------------------------------------------------------------------------------
-- Markierungen und Vorschau
--------------------------------------------------------------------------------

function BuildController:updateHover()
	if self.phase ~= "Build" then
		self.hoverMarker.Transparency = 1
		self.startMarker.Transparency = 1
		self.preview.Transparency = 1
		return
	end

	if self.removeMode then
		self.hoverMarker.Transparency = 1
		self.preview.Transparency = 1
		return
	end

	local index, position = self:findSnapUnderMouse()

	if index and position then
		self.hoverMarker.Position = position
		self.hoverMarker.Transparency = 0.5
	else
		self.hoverMarker.Transparency = 1
	end

	-- Vorschau-Linie zeichnen, sobald der erste Punkt gesetzt ist.
	if self.firstSnap and self.firstSnapPosition then
		self.startMarker.Position = self.firstSnapPosition
		self.startMarker.Transparency = 0.35

		if position and index ~= self.firstSnap then
			local spec = Config.PartTypes[self.selectedKind]
			local delta = position - self.firstSnapPosition
			local length = delta.Magnitude
			local allowed = length >= spec.minLength and length <= spec.maxLength
			if spec.verticalOnly and math.abs(delta.X) > 0.01 then
				allowed = false
			end

			-- Bei senkrechten Bauteilen darf der Hilfsvektor nicht (0,1,0) sein,
			-- sonst liefert CFrame.lookAt kein brauchbares Ergebnis.
			local up = if math.abs(delta.Unit.Y) > 0.999 then Vector3.new(0, 0, 1) else Vector3.new(0, 1, 0)

			self.preview.Size = Vector3.new(0.4, 0.4, length)
			self.preview.CFrame = CFrame.lookAt(self.firstSnapPosition + delta / 2, position, up)
			self.preview.Color = if allowed then Color3.fromRGB(120, 235, 150) else Color3.fromRGB(235, 90, 80)
			self.preview.Transparency = 0.3
		else
			self.preview.Transparency = 1
		end
	else
		self.startMarker.Transparency = 1
		self.preview.Transparency = 1
	end
end

--------------------------------------------------------------------------------
-- Eingaben
--------------------------------------------------------------------------------

function BuildController:cancelSelection()
	self.firstSnap = nil
	self.firstSnapPosition = nil
	self.startMarker.Transparency = 1
	self.preview.Transparency = 1
end

function BuildController:handleLeftClick()
	if self.phase ~= "Build" then
		return
	end

	if self.removeMode then
		local memberId = self:findMemberUnderMouse()
		if memberId then
			self.remotes.RemoveMember:FireServer(memberId)
		end
		return
	end

	local index, position = self:findSnapUnderMouse()
	if not index or not position then
		return
	end

	if not self.firstSnap then
		self.firstSnap = index
		self.firstSnapPosition = position
		return
	end

	if index == self.firstSnap then
		-- Denselben Punkt noch einmal angeklickt: Auswahl verwerfen.
		self:cancelSelection()
		return
	end

	self.remotes.PlaceMember:FireServer(self.selectedKind, self.firstSnap, index)
	self:cancelSelection()
end

function BuildController:handleRightClick()
	if self.phase ~= "Build" then
		return
	end

	-- Steht eine Auswahl offen, bricht der Rechtsklick sie zuerst ab.
	if self.firstSnap then
		self:cancelSelection()
		return
	end

	local memberId = self:findMemberUnderMouse()
	if memberId then
		self.remotes.RemoveMember:FireServer(memberId)
	end
end

function BuildController:connectInput()
	UserInputService.InputBegan:Connect(function(input, processedByGui)
		if processedByGui then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self:handleLeftClick()
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			self:handleRightClick()
		elseif input.KeyCode == Enum.KeyCode.One then
			self:selectKind("Beam")
		elseif input.KeyCode == Enum.KeyCode.Two then
			self:selectKind("Cable")
		elseif input.KeyCode == Enum.KeyCode.Three then
			self:selectKind("Pillar")
		elseif input.KeyCode == Enum.KeyCode.Four then
			self:selectRemoveMode()
		end
	end)
end

--------------------------------------------------------------------------------
-- Auswahl
--------------------------------------------------------------------------------

function BuildController:selectKind(kind: string)
	if not Config.PartTypes[kind] then
		return
	end
	self.selectedKind = kind
	self.removeMode = false
	self:cancelSelection()
	self.gui:setSelected(kind)
end

function BuildController:selectRemoveMode()
	self.removeMode = true
	self:cancelSelection()
	self.gui:setSelected("Remove")
end

function BuildController:setPhase(phase: string)
	self.phase = phase
	if phase ~= "Build" then
		self:cancelSelection()
	end
end

-- Zeigt an, an welchem Ankerpunkt die Last nicht abgetragen werden kann.
function BuildController:setUnstableNode(snapIndex: number?)
	if self.phase ~= "Build" or not snapIndex then
		self.weakMarker.Transparency = 1
		return
	end

	local marker = self.snapFolder:FindFirstChild("Snap_" .. snapIndex)
	if marker then
		self.weakMarker.Position = marker.Position
		self.weakMarker.Transparency = 0.45
	else
		self.weakMarker.Transparency = 1
	end
end

return BuildController
