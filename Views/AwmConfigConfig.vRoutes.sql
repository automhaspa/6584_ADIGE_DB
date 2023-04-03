SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
/**************************/
/********* VISTE ***********/
CREATE VIEW [AwmConfigConfig].[vRoutes]
AS SELECT r.route, r.moduleId, r.resourceName, r.resourceNameMain, r.colour, r.nav, r.hash FROM AwmConfig.Routes r
GO
