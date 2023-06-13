SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


CREATE view [AwmConfig].[vDestinazioniIngombranti] 
AS 
SELECT	ID_PARTIZIONE	Id_Partizione,
		CASE WHEN P.DESCRIZIONE LIKE '%ADIGE 1%' THEN 'ADIGE 1' ELSE  sc.DESCRIZIONE END		DESCRIZIONE,
		sc.PIANO,
		sc.COLONNA
FROM	Partizioni			p
JOIN	SottoComponenti		sc
ON		p.ID_SOTTOCOMPONENTE = sc.ID_SOTTOCOMPONENTE
JOIN	Componenti			c
ON		c.ID_COMPONENTE = sc.ID_COMPONENTE
WHERE	((p.DESCRIZIONE LIKE '8A%'
	AND p.CODICE_ABBREVIATO = '0001')
	OR P.DESCRIZIONE LIKE '%ADIGE 1%')
	AND ID_TIPO_PARTIZIONE = 'MI'
GO
