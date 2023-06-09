SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE FUNCTION [dbo].[isEmptyUdc]
	(@Id_Udc INT)
RETURNS bit
AS
BEGIN
	RETURN	CAST(
					CASE (SELECT ISNULL(SUM(Quantita_Pezzi),0) FROM dbo.Udc_Dettaglio WHERE Id_Udc = @Id_Udc)
						WHEN 0 THEN 1
						ELSE 0
					END	
					AS BIT
				)
END
GO
