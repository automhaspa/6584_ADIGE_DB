CREATE TABLE [dbo].[Adiacenze_Composte]
(
[Id_Adiacenza] [int] NOT NULL,
[Sequenza] [int] NOT NULL,
[Descrizione] [varchar] (80) COLLATE Latin1_General_CI_AS NOT NULL,
[Id_Partizione_Sorgente] [int] NULL,
[Id_Partizione_Destinazione] [int] NULL,
[Id_Tipo_Messaggio] [varchar] (5) COLLATE Latin1_General_CI_AS NULL,
[Stored_Procedure] [varchar] (50) COLLATE Latin1_General_CI_AS NULL,
[Xml_Param] [xml] NULL,
[Inserimento] [varchar] (1) COLLATE Latin1_General_CI_AS NOT NULL,
[Abilitata] [bit] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Adiacenze_Composte] ADD CONSTRAINT [CK_Adiacenze_Composte] CHECK (([Inserimento]='B' OR [Inserimento]='A'))
GO
ALTER TABLE [dbo].[Adiacenze_Composte] ADD CONSTRAINT [PK_Adiacenze_Composte] PRIMARY KEY CLUSTERED ([Id_Adiacenza], [Sequenza]) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Adiacenze_Composte] ADD CONSTRAINT [FK_Adiacenze_Composte_Adiacenze] FOREIGN KEY ([Id_Adiacenza]) REFERENCES [dbo].[Adiacenze] ([Id_Adiacenza])
GO
ALTER TABLE [dbo].[Adiacenze_Composte] ADD CONSTRAINT [FK_Adiacenze_Composte_Tipo_Messaggi] FOREIGN KEY ([Id_Tipo_Messaggio]) REFERENCES [dbo].[Tipo_Messaggi] ([Id_Tipo_Messaggio])
GO
EXEC sp_addextendedproperty N'MS_Description', N'Indica quando deve essere inserito A = AFTER B = BEFORE', 'SCHEMA', N'dbo', 'TABLE', N'Adiacenze_Composte', 'COLUMN', N'Inserimento'
GO
