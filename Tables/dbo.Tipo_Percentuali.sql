CREATE TABLE [dbo].[Tipo_Percentuali]
(
[Id_Percentuale] [int] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Tipo_Percentuali] ADD CONSTRAINT [PK_Tipo_Percentuali] PRIMARY KEY CLUSTERED ([Id_Percentuale]) ON [PRIMARY]
GO
