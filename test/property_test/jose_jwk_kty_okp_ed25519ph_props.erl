%% -*- mode: erlang; tab-width: 4; indent-tabs-mode: nil; st-rulers: [132] -*-
%% vim: ts=4 sw=4 ft=erlang et
-module(jose_jwk_kty_okp_ed25519ph_props).

-include_lib("public_key/include/public_key.hrl").

-include_lib("proper/include/proper.hrl").

% -compile(export_all).

base64url_binary() ->
	?LET(Binary,
		binary(),
		jose_jwa_base64url:encode(Binary)).

binary_map() ->
	?LET(List,
		list({base64url_binary(), base64url_binary()}),
		maps:from_list(List)).

ed25519ph_secret() ->
	binary(32).

ed25519ph_keypair(Secret) ->
	{PK, SK} = jose_curve25519:eddsa_keypair(Secret),
	{SK, PK}.

jwk_map() ->
	?LET({AliceSecret, BobSecret},
		{ed25519ph_secret(), ed25519ph_secret()},
		begin
			AliceKeys = {AlicePrivateKey, _} = ed25519ph_keypair(AliceSecret),
			BobKeys = ed25519ph_keypair(BobSecret),
			AlicePrivateJWK = jose_jwk:from_okp({'Ed25519ph', AlicePrivateKey}),
			{_, AlicePrivateJWKMap} = jose_jwk:to_map(AlicePrivateJWK),
			Keys = {AliceKeys, BobKeys},
			{Keys, AlicePrivateJWKMap}
		end).

jwk_gen() ->
	?LET({Keys, AlicePrivateJWKMap},
		jwk_map(),
		{Keys, jose_jwk:from_map(AlicePrivateJWKMap)}).

prop_from_map_and_to_map() ->
	?FORALL({{{AlicePrivateKey, AlicePublicKey}, _}, AlicePrivateJWKMap},
		?LET({{Keys, JWKMap}, Extras},
			{jwk_map(), binary_map()},
			{Keys, maps:merge(Extras, JWKMap)}),
		begin
			AlicePrivateJWK = jose_jwk:from_map(AlicePrivateJWKMap),
			AlicePublicJWK = jose_jwk:to_public(AlicePrivateJWK),
			AlicePublicJWKMap = element(2, jose_jwk:to_map(AlicePublicJWK)),
			AlicePublicThumbprint = jose_jwk:thumbprint(AlicePublicJWK),
			AlicePrivateJWKMap =:= element(2, jose_jwk:to_map(AlicePrivateJWK))
			andalso AlicePrivateKey =:= element(2, jose_jwk:to_key(AlicePrivateJWK))
			andalso AlicePublicKey =:= element(2, jose_jwk:to_public_key(AlicePrivateJWK))
			andalso AlicePublicJWKMap =:= element(2, jose_jwk:to_public_map(AlicePrivateJWK))
			andalso AlicePublicThumbprint =:= jose_jwk:thumbprint(AlicePrivateJWK)
		end).

prop_sign_and_verify() ->
	?FORALL({_Keys, JWK, Message},
		?LET({Keys, JWK},
			jwk_gen(),
			{Keys, JWK, binary()}),
		begin
			Signed = jose_jwk:sign(Message, JWK),
			CompactSigned = jose_jws:compact(Signed),
			Verified = {_, _, JWS} = jose_jwk:verify(Signed, JWK),
			{true, Message, JWS} =:= Verified
			andalso {true, Message, JWS} =:= jose_jwk:verify(CompactSigned, JWK)
		end).
