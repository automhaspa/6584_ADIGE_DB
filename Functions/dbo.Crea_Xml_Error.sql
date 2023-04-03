SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO


-- =============================================
-- Author:		Ugo Volpato
-- Create date: 03/04/2009
-- Description:	Crea l'Xml dell'errore a partire dai parametri.
-- =============================================
CREATE FUNCTION [dbo].[Crea_Xml_Error](
	  @Error_Number					Int
	, @Error_Message				Nvarchar(2400)  = NULL
	, @Error_State					Int				= 0
	, @Nome_StoredProcedure			Varchar(100)	= NULL
	, @CodPlc						Varchar(14)		= NULL
	, @Xml_Param					Xml				= NULL
	, @Id_Tipo_Check_Evento			Int				= NULL)
RETURNS Xml
AS
BEGIN
	DECLARE @XmlErrore Xml
	SET @XmlErrore = '<Error/>'
	SET @XmlErrore.modify('insert <Error_Number>{sql:variable("@Error_Number")}</Error_Number> into (/Error)[1]')
	SET @XmlErrore.modify('insert <Error_Message>{sql:variable("@Error_Message")}</Error_Message> into (/Error)[1]')
	SET @XmlErrore.modify('insert <Error_State>{sql:variable("@Error_State")}</Error_State> into (/Error)[1]')
	SET @XmlErrore.modify('insert <Nome_StoredProcedure>{sql:variable("@Nome_StoredProcedure")}</Nome_StoredProcedure> into (/Error)[1]')
	SET @XmlErrore.modify('insert <CodPlc>{sql:variable("@CodPlc")}</CodPlc> into (/Error)[1]')
			
	SET @XmlErrore = CONVERT(XML, (CONVERT(nvarchar(MAX), @XmlErrore) + CONVERT(nvarchar(MAX), ISNULL(@Xml_Param,''))))
	IF @Xml_Param.exist('/Xml_Param') = 0
		BEGIN
			SET @XmlErrore.modify('insert <Xml_Param /> into (/Error)[1]')
			SET @XmlErrore.modify('insert /*[2] as first into (/Error/Xml_Param)[1]')
		END
	ELSE
		BEGIN
			SET @XmlErrore.modify('insert /*[2] as last into (/Error)[1]')
		END
	SET @XmlErrore.modify('delete /*[2]')

	SET @XmlErrore.modify('insert <Id_Tipo_Check_Evento>{sql:variable("@Id_Tipo_Check_Evento")}</Id_Tipo_Check_Evento> into (/Error)[1]')
	
	RETURN @XmlErrore

END



GO
