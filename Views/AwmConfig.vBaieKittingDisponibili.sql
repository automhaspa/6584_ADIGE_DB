SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE VIEW [AwmConfig].[vBaieKittingDisponibili]
AS
SELECT	Id_Partizione,
		Id_Testata_Lista,
		Id_Udc,
		DESCRIZIONE,
		Codice_Udc,
		ORDER_ID,
		ORDER_TYPE,
		KIT_ID
FROM	AwmConfig.vBaieKitting
WHERE	Id_Udc IS NULL
GO
