class_name ServerSession
extends RefCounted
## La sesión con el servidor: los dos "pases" que da Nakama al entrar.
##
## - token: pase corto (2 horas) que va en cada pedido.
## - refresh_token: pase largo (1 año) para pedir un token nuevo sin la
##   contraseña. Cada renovación trae uno nuevo, así que no se vence mientras
##   se juegue ("acceso único").
##
## Los dos son JWT: tres partes separadas por puntos; la del medio es un JSON
## (en base64) con la fecha de vencimiento ("exp"), el id ("uid") y el nombre
## de usuario ("usn"). Aquí solo se LEEN; el servidor es quien los firma.
## La contraseña nunca se guarda.

var token := ""
var refresh_token := ""
var user_id := ""
var username := ""
## Vencimientos en segundos Unix.
var token_exp := 0
var refresh_exp := 0


## Crea la sesión a partir de la respuesta del servidor ({token, refresh_token}).
static func from_tokens(new_token: String, new_refresh_token: String) -> ServerSession:
	var session := ServerSession.new()
	session.update_tokens(new_token, new_refresh_token)
	return session


## Cambia los pases (al renovar). Un refresh_token vacío deja el anterior.
func update_tokens(new_token: String, new_refresh_token: String) -> void:
	token = new_token
	var claims := parse_claims(token)
	token_exp = int(claims.get("exp", 0))
	user_id = claims.get("uid", user_id)
	username = claims.get("usn", username)
	if new_refresh_token != "":
		refresh_token = new_refresh_token
		refresh_exp = int(parse_claims(refresh_token).get("exp", 0))


func is_valid() -> bool:
	return token != "" and refresh_token != "" and user_id != ""


## ¿El token corto vence dentro de `margin` segundos (o ya venció)?
func token_expiring(now: int, margin := 60) -> bool:
	return now + margin >= token_exp


func refresh_expired(now: int) -> bool:
	return now >= refresh_exp


## Lee los datos de un JWT. Devuelve {} si no tiene la forma esperada.
static func parse_claims(jwt: String) -> Dictionary:
	var parts := jwt.split(".")
	if parts.size() != 3:
		return {}
	# base64 "para URL": usa - y _ en vez de + y /, y no trae relleno "=".
	var payload := parts[1].replace("-", "+").replace("_", "/")
	while payload.length() % 4 != 0:
		payload += "="
	var data: Variant = JSON.parse_string(Marshalls.base64_to_utf8(payload))
	return data if data is Dictionary else {}


func to_dict() -> Dictionary:
	return {"token": token, "refresh_token": refresh_token}


static func from_dict(data: Dictionary) -> ServerSession:
	return from_tokens(data.get("token", ""), data.get("refresh_token", ""))
