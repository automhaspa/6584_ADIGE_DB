CREATE TABLE [dbo].[Tipo_ErrorCode]
(
[Id_ErrorCode] [int] NOT NULL,
[Descrizione] [varchar] (120) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Tipo_ErrorCode] ADD CONSTRAINT [PK_Tipo_ErrorCode] PRIMARY KEY CLUSTERED ([Id_ErrorCode]) ON [PRIMARY]
GO
