local CurrentWeather = Config.Weather
local CurrentTime = Config.Time
local CurrentTimescale = Config.Timescale
local WeatherPattern = Config.WeatherPattern
local WeatherInterval = Config.WeatherInterval
local TimeIsFrozen = Config.TimeIsFrozen
local WeatherIsFrozen = Config.WeatherIsFrozen
local MaxForecast = Config.MaxForecast
local SyncDelay = Config.SyncDelay
local CurrentWindDirection = Config.WindDirection
local CurrentWindSpeed = Config.WindSpeed
local WindIsFrozen = Config.WindIsFrozen
local PermanentSnow = Config.PermanentSnow

local WeatherTicks = 0
local WeatherForecast = {}

local DayLength = 86400
local WeekLength = 604800

RegisterNetEvent('weatherSync:init')
RegisterNetEvent('weatherSync:requestUpdatedForecast')
RegisterNetEvent('weatherSync:requestUpdatedAdminUi')
RegisterNetEvent('weatherSync:setTime')
RegisterNetEvent('weatherSync:resetTime')
RegisterNetEvent('weatherSync:setTimescale')
RegisterNetEvent('weatherSync:resetTimescale')
RegisterNetEvent('weatherSync:setWeather')
RegisterNetEvent('weatherSync:resetWeather')
RegisterNetEvent('weatherSync:setWeatherPattern')
RegisterNetEvent('weatherSync:resetWeatherPattern')
RegisterNetEvent('weatherSync:setWind')
RegisterNetEvent('weatherSync:resetWind')
RegisterNetEvent('weatherSync:setSyncDelay')
RegisterNetEvent('weatherSync:resetSyncDelay')

function NextWeather(weather)
	if WeatherIsFrozen then
		return weather
	end

	local choices = WeatherPattern[weather]

	if not choices then
		return weather
	end

	local c = 0
	local r = math.random(1, 100)

	for weatherType, chance in pairs(choices) do
		c = c + chance
		if r <= c then
			return weatherType
		end
	end

	return weather
end

function NextWindDirection(direction)
	if WindIsFrozen then
		return direction
	end

	return ((direction + math.random(0, 90) - 45) % 360) * 1.0
end

function GenerateForecast()
	local weather = NextWeather(CurrentWeather)
	local wind = NextWindDirection(CurrentWindDirection)

	WeatherForecast = {{weather = weather, wind = wind}}

	for i = 2, MaxForecast do
		weather = NextWeather(weather)
		wind = NextWindDirection(wind)
		WeatherForecast[i] = {weather = weather, wind = wind}
	end
end

function Contains(t, x)
	for _, v in pairs(t) do
		if v == x then
			return true
		end
	end
	return false
end

function PrintMessage(target, message)
	if target and target > 0 then
		TriggerClientEvent('chat:addMessage', target, message)
	else
		print(table.concat(message.args, ': '))
	end
end

function SetWeather(weather, transition, freeze, permanentSnow)
	TriggerClientEvent('weatherSync:changeWeather', -1, weather, transition, permanentSnow)
	CurrentWeather = weather
	WeatherIsFrozen = freeze
	PermanentSnow = permanentSnow
	GenerateForecast()
end

RegisterCommand('weather', function(source, args, raw)
	local weather = (args[1] and args[1] or CurrentWeather)
	local transition = (args[2] and tonumber(args[2]) or 10.0)
	local freeze = args[3] == '1'
	local permanentSnow = args[4] == '1'

	if transition <= 0.0 then
		transition = 0.1
	end

	if Contains(WeatherTypes, weather) then
		SetWeather(weather, transition * 1.0, freeze, permanentSnow)
	else
		PrintMessage(source, {color = {255, 0, 0}, args = {'Error', 'Unknown weather type: ' .. weather}})
	end
end, true)

AddEventHandler('weatherSync:setWeather', function(weather, transition, freeze, permanentSnow)
	SetWeather(weather, transition, freeze, permanentSnow)
end)

function ResetWeather()
	CurrentWeather = Config.Weather
	WeatherIsFrozen = Config.WeatherIsFrozen
	PermanentSnow = Config.PermanentSnow
	GenerateForecast()
end

AddEventHandler('weatherSync:resetWeather', ResetWeather)

function GetWeather()
	return CurrentWeather
end

local LogColors = {
	['name'] = '\x1B[32m',
	['default'] = '\x1B[0m',
	['error'] = '\x1B[31m',
	['success'] = '\x1B[32m'
}

function Log(label, message)
	local color = LogColors[label]

	if not color then
		color = LogColors.default
	end

	print(string.format('%s[WeatherSync] %s[%s]%s %s', LogColors.name, color, label, LogColors.default, message))
end

function ValidateWeatherPattern(pattern)
	for weather, choices in pairs(pattern) do
		if not pattern[weather] then
			Log('error', weather .. ' is missing from the weather pattern table')
		end

		local sum = 0

		for nextWeather, chance in pairs(choices) do
			sum = sum + chance
		end

		if sum ~= 100 then
			Log('error', weather .. ' next stages do not add up to 100')
		end
	end
end

function SetWeatherPattern(pattern)
	ValidateWeatherPattern(pattern)
	WeatherPattern = pattern
	GenerateForecast()
end

AddEventHandler('weatherSync:setWeatherPattern', function(pattern)
	SetWeatherPattern(pattern)
end)

function ResetWeatherPattern()
	WeatherPattern = Config.WeatherPattern
	GenerateForecast()
end

AddEventHandler('weatherSync:resetWeatherPattern', ResetWeatherPattern)

function SetTime(d, h, m, s, t, f)
	TriggerClientEvent('weatherSync:changeTime', -1, h, m, s, t, true)
	CurrentTime = DHMSToTime(d, h, m, s)
	TimeIsFrozen = f
end

RegisterCommand('time', function(source, args, raw)
	if #args > 0 then
		local d = (args[1] and tonumber(args[1]) or 0)
		local h = (args[2] and tonumber(args[2]) or 0)
		local m = (args[3] and tonumber(args[3]) or 0)
		local s = (args[4] and tonumber(args[4]) or 0)
		local t = (args[5] and tonumber(args[5]) or 0)
		local f = args[6] == '1'

		SetTime(d, h, m, s, t, f)
	else
		local d, h, m, s = TimeToDHMS(CurrentTime)
		PrintMessage(source, {color = {255, 255, 128}, args = {'Time', string.format('%s %.2d:%.2d:%.2d', GetDayOfWeek(d), h, m, s)}})
	end
end, true)

AddEventHandler('weatherSync:setTime', function(d, h, m, s, t, f)
	SetTime(d, h, m, s, t, f)
end)

function ResetTime()
	CurrentTime = Config.Time
	TimeIsFrozen = Config.TimeIsFrozen
end

AddEventHandler('weatherSync:resetTime', ResetTime())

function GetTime()
	local d, h, m, s = TimeToDHMS(CurrentTime)
	return {day = d, hour = h, minute = m, second = s}
end

function SetTimescale(scale)
	CurrentTimescale = scale
end

RegisterCommand('timescale', function(source, args, raw)
	if args[1] then
		SetTimescale(tonumber(args[1]) * 1.0)
	else
		PrintMessage(source, {color = {255, 255, 128}, args = {'Timescale', CurrentTimescale}})
	end
end, true)

AddEventHandler('weatherSync:setTimescale', function(scale)
	SetTimescale(scale)
end)

function ResetTimescale()
	CurrentTimescale = Config.Timescale
end

AddEventHandler('weatherSync:resetTimescale', ResetTimescale)

function SetSyncDelay(delay)
	SyncDelay = delay
end

RegisterCommand('syncdelay', function(source, args, raw)
	if args[1] then
		SetSyncDelay(tonumber(args[1]))
	else
		PrintMessage(source, {color = {255, 255, 128}, args = {'Sync delay', SyncDelay}})
	end
end, true)

AddEventHandler('weatherSync:setSyncDelay', function(delay)
	SetSyncDelay(delay)
end)

function ResetSyncDelay()
	SyncDelay = Config.SyncDelay
end

AddEventHandler('weatherSync:resetSyncDelay', ResetSyncDelay)

function SetWind(direction, speed, frozen)
	CurrentWindDirection = direction
	CurrentWindSpeed = speed
	WindIsFrozen = frozen
	GenerateForecast()
end

RegisterCommand('wind', function(source, args, raw)
	if #args > 0 then
		local direction = tonumber(args[1]) * 1.0
		local speed = (args[2] and tonumber(args[2]) * 1.0 or 0.0)
		local frozen = args[3] == '1'
		SetWind(direction, speed, frozen)
	end
end, true)

AddEventHandler('weatherSync:setWind', function(direction, speed, frozen)
	SetWind(direction, speed, frozen)
end)

function ResetWind()
	CurrentWindDirection = Config.WindDirection
	CurrentWindSpeed = Config.WindSpeed
	WindIsFrozen = Config.WindIsFrozen
	GenerateForecast()
end

AddEventHandler('weatherSync:resetWind', ResetWind)

function GetWind()
	return {direction = CurrentWindDirection, speed = CurrentWindSpeed}
end

function CreateForecast()
	local forecast = {}

	for i = 0, #WeatherForecast do
		local d, h, m, s, weather, wind

		if i == 0 then
			d, h, m, s = TimeToDHMS(CurrentTime)
			weather = CurrentWeather
			wind = CurrentWindDirection
		else
			local time = (TimeIsFrozen and CurrentTime or (CurrentTime + WeatherInterval * i) % WeekLength)
			d, h, m, s = TimeToDHMS(time - time % WeatherInterval)
			weather = WeatherForecast[i].weather
			wind = WeatherForecast[i].wind
		end

		table.insert(forecast, {day = d, hour = h, minute = m, second = s, weather = weather, wind = wind})
	end

	return forecast
end

RegisterCommand('forecast', function(source, args, raw)
	if source and source > 0 then
		TriggerClientEvent('weatherSync:toggleForecast', source)
	else
		local forecast = CreateForecast()
		PrintMessage(source, {args = {'WEATHER FORECAST'}})
		PrintMessage(source, {args = {'================'}})
		for i = 1, #forecast do
			local time = string.format('%s %.2d:%.2d', GetDayOfWeek(forecast[i].day), forecast[i].hour, forecast[i].minute)
			PrintMessage(source, {args = {time, forecast[i].weather}})
		end
		PrintMessage(source, {args = {'================'}})
	end
end, true)

AddEventHandler('weatherSync:requestUpdatedForecast', function()
	TriggerClientEvent('weatherSync:updateForecast', source, CreateForecast())
end)

AddEventHandler('weatherSync:requestUpdatedAdminUi', function()
	TriggerClientEvent('weatherSync:updateAdminUi', source, CurrentWeather, CurrentTime, CurrentTimescale, CurrentWindDirection, CurrentWindSpeed, SyncDelay)
end)

function SyncTime(player, tick)
	-- Ensure time doesn't wrap around when transitioning from ~23:59:59 to ~00:00:00
	local timeTransition = ((DayLength - (CurrentTime % DayLength) + tick) % DayLength <= tick and 0 or SyncDelay)
	local day, hour, minute, second = TimeToDHMS(CurrentTime)
	TriggerClientEvent('weatherSync:changeTime', player, hour, minute, second, timeTransition, false)
end

function SyncWeather(player)
	TriggerClientEvent('weatherSync:changeWeather', player, CurrentWeather, WeatherInterval / CurrentTimescale / 4, PermanentSnow)
end

function SyncWind(player)
	TriggerClientEvent('weatherSync:changeWind', player, CurrentWindDirection, CurrentWindSpeed)
end

AddEventHandler('weatherSync:init', function()
	SyncTime(source, 0)
	SyncWeather(source)
	SyncWind(source)
end)

RegisterCommand('weatherui', function(source, args, raw)
	TriggerClientEvent('weatherSync:openAdminUi', source)
end, true)

RegisterCommand('weathersync', function(source, args, raw)
	TriggerClientEvent('weatherSync:toggleSync', source)
end, true)

RegisterCommand('mytime', function(source, args, raw)
	local h = (args[1] and tonumber(args[1]) or 0)
	local m = (args[2] and tonumber(args[2]) or 0)
	local s = (args[3] and tonumber(args[3]) or 0)
	local t = (args[4] and tonumber(args[4]) or 0)
	TriggerClientEvent('weatherSync:setMyTime', source, h, m, s, t)
end, true)

RegisterCommand('myweather', function(source, args, raw)
	local weather = (args[1] and args[1] or CurrentWeather)
	local transition = (args[2] and tonumber(args[2]) or 5.0)
	local permanentSnow = args[3] == '1'
	TriggerClientEvent('weatherSync:setMyWeather', source, weather, transition, permanentSnow)
end, true)

exports('getTime', GetTime)
exports('setTime', SetTime)
exports('resetTime', ResetTime)
exports('setTimescale', SetTimescale)
exports('resetTimescale', ResetTimescale)
exports('getWeather', GetWeather)
exports('setWeather', SetWeather)
exports('resetWeather', ResetWeather)
exports('setWeatherPattern', SetWeatherPattern)
exports('resetWeatherPattern', ResetWeatherPattern)
exports('getWind', GetWind)
exports('setWind', SetWind)
exports('resetWind', ResetWind)
exports('setSyncDelay', SetSyncDelay)
exports('resetSyncDelay', ResetSyncDelay)
exports('getForecast', CreateForecast)

Citizen.CreateThread(function()
	ValidateWeatherPattern(WeatherPattern)

	GenerateForecast()

	while true do
		Citizen.Wait(SyncDelay)

		local tick = CurrentTimescale * (SyncDelay / 1000)

		if not TimeIsFrozen then
			CurrentTime = math.floor(CurrentTime + tick) % WeekLength
		end

		if not WeatherIsFrozen then
			if WeatherTicks >= WeatherInterval then
				local next = table.remove(WeatherForecast, 1)
				local last = WeatherForecast[#WeatherForecast]

				CurrentWeather = next.weather
				CurrentWindDirection = next.wind

				table.insert(WeatherForecast, {
					weather = NextWeather(last.weather),
					wind = NextWindDirection(last.wind)
				})

				WeatherTicks = 0
			else
				WeatherTicks = WeatherTicks + tick
			end
		end

		SyncTime(-1, tick)
		SyncWeather(-1)
		SyncWind(-1)
	end
end)
