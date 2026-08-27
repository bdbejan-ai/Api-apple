--[[
	Monetisation
	------------
	Kauf von Tipps mit Robux.

	WIE ES FUNKTIONIERT
	Ein Kauf gibt dem Spieler KEINEN bestimmten Tipp, sondern einen
	"Tipp-Gutschein" (hintCredit). Beim naechsten kostenpflichtigen Tipp wird
	ein Gutschein eingeloest. Das ist deutlich robuster: der Kauf muss nicht
	wissen, in welchem Level der Spieler gerade steht, und ein Kauf geht auch
	dann nicht verloren, wenn der Spieler zwischendurch das Level wechselt.

	WARUM DAS SORGFAELTIG SEIN MUSS
	Hier fliesst echtes Geld. Roblox ruft ProcessReceipt so lange erneut auf,
	bis wir PurchaseGranted zurueckgeben. Zwei Fehler waeren moeglich:
	  - Wir geben PurchaseGranted zurueck, ohne den Gutschein zu vergeben
	    -> der Spieler hat bezahlt und nichts bekommen.
	  - Wir vergeben den Gutschein mehrfach, weil derselbe Beleg mehrfach
	    ankommt -> der Spieler bekommt mehr, als er bezahlt hat.
	Deshalb wird jeder Beleg (PurchaseId) in einem eigenen DataStore vermerkt,
	und zwar mit UpdateAsync - das ist der einzige Weg, der auch dann richtig
	bleibt, wenn zwei Server gleichzeitig denselben Beleg bearbeiten.
]]

local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("BridgeLab")
local Config = require(Shared.Config)

local PlayerData = require(script.Parent.PlayerData)

local Monetisation = {}

-- Wird von init.server.luau gesetzt: Rueckmeldung an den Client nach einem Kauf.
Monetisation.onCreditGranted = nil :: ((Player) -> ())?

local receiptStore = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.Data.receiptStoreName)
	end)
	if ok then
		receiptStore = result
	else
		warn("[BridgeLab] Beleg-DataStore nicht verfuegbar.")
	end
end

--------------------------------------------------------------------------------
-- Ist der Kauf ueberhaupt eingerichtet?
--------------------------------------------------------------------------------

function Monetisation.isConfigured(): boolean
	return (Config.Monetisation.hintProductId or 0) > 0
end

--------------------------------------------------------------------------------
-- Beleg genau einmal einloesen
--------------------------------------------------------------------------------

--[[
	Vermerkt den Beleg und sagt, ob ER NEU WAR.
	Rueckgabe:
	  true, true   -> Zugriff geklappt, Beleg war neu   -> jetzt gutschreiben
	  true, false  -> Zugriff geklappt, Beleg war schon da -> nichts tun
	  false, nil   -> Zugriff fehlgeschlagen -> spaeter erneut versuchen
]]
local function claimReceipt(receiptKey: string): (boolean, boolean?)
	if not receiptStore then
		return false, nil
	end

	local wasNew = false
	local ok, err = pcall(function()
		receiptStore:UpdateAsync(receiptKey, function(existing)
			if existing then
				wasNew = false
				return nil -- nichts aendern
			end
			wasNew = true
			return os.time()
		end)
	end)

	if not ok then
		warn("[BridgeLab] Beleg konnte nicht geprueft werden: " .. tostring(err))
		return false, nil
	end
	return true, wasNew
end

--------------------------------------------------------------------------------
-- ProcessReceipt
--------------------------------------------------------------------------------

local function processReceipt(receiptInfo)
	-- Nur unser eigenes Produkt bearbeiten.
	if receiptInfo.ProductId ~= Config.Monetisation.hintProductId then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		-- Spieler ist gerade nicht da. Roblox fragt spaeter erneut.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if not PlayerData.get(player) then
		-- Profil noch nicht geladen: lieber warten als etwas verlieren.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local receiptKey = string.format("%d_%s", receiptInfo.PlayerId, tostring(receiptInfo.PurchaseId))

	--[[
		In Studio gibt es haeufig keinen DataStore-Zugriff. Dort sind Kaeufe
		ohnehin nicht echt, also schreiben wir direkt gut, damit man den
		Ablauf testen kann. Im veroeffentlichten Spiel ist der Beleg-Vermerk
		dagegen Pflicht - ohne ihn geben wir NICHT frei, sondern lassen Roblox
		spaeter erneut fragen.
	]]
	if RunService:IsStudio() and not receiptStore then
		PlayerData.addHintCredits(player, 1)
		if Monetisation.onCreditGranted then
			Monetisation.onCreditGranted(player)
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local accessed, wasNew = claimReceipt(receiptKey)
	if not accessed then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if wasNew then
		PlayerData.addHintCredits(player, 1)
		PlayerData.save(player)
		if Monetisation.onCreditGranted then
			Monetisation.onCreditGranted(player)
		end
	end

	-- Auch ein bereits bekannter Beleg gilt als erledigt - sonst fragt Roblox
	-- endlos weiter.
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- ProcessReceipt darf es nur EINMAL im ganzen Spiel geben.
MarketplaceService.ProcessReceipt = processReceipt

return Monetisation
