CREATE TABLE [AwmConfig].[Routes]
(
[route] [nvarchar] (50) COLLATE Latin1_General_CI_AS NOT NULL,
[moduleId] [nvarchar] (50) COLLATE Latin1_General_CI_AS NOT NULL,
[resourceName] [nvarchar] (50) COLLATE Latin1_General_CI_AS NULL,
[resourceNameMain] [nvarchar] (50) COLLATE Latin1_General_CI_AS NULL,
[colour] [varchar] (50) COLLATE Latin1_General_CI_AS NULL,
[nav] [int] NULL,
[hash] [varchar] (250) COLLATE Latin1_General_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [AwmConfig].[Routes] ADD CONSTRAINT [PK_Routers_1] PRIMARY KEY CLUSTERED ([hash]) ON [PRIMARY]
GO
