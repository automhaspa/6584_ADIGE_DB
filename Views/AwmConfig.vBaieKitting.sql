SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE   view [AwmConfig].[vBaieKitting]
AS
SELECT	P.ID_PARTIZIONE			Id_Partizione,
		okb.Id_Testata_Lista,
		up.Id_Udc,
		p.DESCRIZIONE,
		ut.Codice_Udc			Codice_Udc,
		tlp.ORDER_ID			ORDER_ID,
		tlp.ORDER_TYPE			ORDER_TYPE,
		CASE
			WHEN tlp.ID IS NOT NULL THEN okb.Kit_Id
			ELSE NULL
		END						KIT_ID
FROM	Partizioni					p
LEFT
JOIN	Custom.OrdineKittingBaia	okb
ON		okb.Id_Partizione = p.ID_PARTIZIONE
LEFT
JOIN	Custom.OrdineKittingUdc		oku
ON		oku.Id_Testata_Lista = okb.Id_Testata_Lista
	AND oku.Kit_Id = okb.Kit_Id
LEFT
JOIN	Custom.TestataListePrelievo tlp
ON		tlp.ID = okb.Id_Testata_Lista
LEFT
JOIN	Udc_Posizione				up
ON		up.Id_Udc = oku.Id_Udc
LEFT
JOIN	Udc_Testata					ut
ON		ut.Id_Udc = up.Id_Udc
WHERE	ID_TIPO_PARTIZIONE = 'KT'
	AND ISNULL(tlp.Stato,1) IN (1,2)
	AND ISNULL(oku.Stato_Udc_Kit,1) = 1
GROUP
	BY	p.ID_PARTIZIONE,
		up.Id_Udc,
		tlp.ID,
		p.DESCRIZIONE,
		ut.Codice_Udc,
		tlp.ORDER_ID,
		tlp.ORDER_TYPE,
		okb.Kit_Id,
		okb.Id_Testata_Lista
GO
