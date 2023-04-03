CREATE TABLE [dbo].[Tipo_Priorita]
(
[Priorita] [int] NOT NULL,
[Descrizione] [varchar] (100) COLLATE Latin1_General_CI_AS NULL,
[Icona] [varchar] (150) COLLATE Latin1_General_CI_AS NULL,
[Selectable] [bit] NULL CONSTRAINT [DF_Tipo_Priorita_Selectable] DEFAULT ((1))
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Tipo_Priorita] ADD CONSTRAINT [PK_Tipo_Priorita] PRIMARY KEY CLUSTERED ([Priorita]) ON [PRIMARY]
GO
