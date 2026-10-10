package com.medha.companion.ui.reader

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Sync
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.medha.companion.data.model.Block

/**
 * High-performance Material 3 Document Reader displaying hierarchical note blocks with smooth scrolling.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DocumentReaderScreen(
    documentTitle: String,
    notebookName: String = "Default Notebook",
    blocks: List<Block>,
    onBackClick: () -> Unit = {},
    onSearchClick: () -> Unit = {},
    onSyncClick: () -> Unit = {},
    onToggleTodo: (String, Boolean) -> Unit = { _, _ -> }
) {
    // Map block parent hierarchies to calculate depth level
    val depthMap = mutableMapOf<String, Int>()
    fun getDepth(parentId: String?): Int {
        if (parentId == null) return 0
        return depthMap.getOrPut(parentId) {
            val parentBlock = blocks.firstOrNull { it.id == parentId }
            if (parentBlock != null) getDepth(parentBlock.parentId) + 1 else 0
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Box {
                        Text(
                            text = documentTitle,
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                    }
                },
                navigationIcon = {
                    IconButton(onClick = onBackClick) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Back"
                        )
                    }
                },
                actions = {
                    IconButton(onClick = onSearchClick) {
                        Icon(
                            imageVector = Icons.Default.Search,
                            contentDescription = "Search Notes"
                        )
                    }
                    IconButton(onClick = onSyncClick) {
                        Icon(
                            imageVector = Icons.Default.Sync,
                            contentDescription = "Sync"
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface,
                    titleContentColor = MaterialTheme.colorScheme.onSurface
                )
            )
        }
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp)
        ) {
            items(blocks, key = { it.id }) { block ->
                val depth = getDepth(block.parentId)
                BlockItem(
                    block = block,
                    depth = depth,
                    onToggleTodo = onToggleTodo
                )
            }
        }
    }
}
