SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
-- =============================================
-- Author:		Andrea Peraboni
-- Create date: 05.10.2015
-- Description:	Funzione usata nella vista CDL_Users
--				Data UserId di un utente restituisce
--				una stringa di tutte le autorizzazione
--				dell'utente
-- =============================================
CREATE FUNCTION [dbo].[getAllUserRoles]
(
	@UserId	NVARCHAR(50)
)
RETURNS NVARCHAR(MAX)
AS
BEGIN

	DECLARE @fResult	NVARCHAR(MAX);
 
	SELECT
		@fResult = ISNULL(@fResult + ', ', '') + Role
		FROM
			UsersRoles
		WHERE
			UserId = @UserId
		ORDER BY
			Role;


	RETURN @fResult;

END
GO
