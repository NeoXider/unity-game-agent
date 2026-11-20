// Editor-only audit from unity-game-agent tools/asset-restyle.md. Copy into an Editor folder.
// Acceptance: Tools > Audit > Image Slicing logs "[]" in Edit Mode and in Play Mode.

using System;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;

namespace Project.EditorTools
{
    public static class ImageSliceAudit
    {
        // Set to the folder that holds the restyled sprites; only Images using sprites from it are audited.
        private const string ArtRoot = "Assets/_source/Art/MVPStyle/";
        // Sprites whose center is a texture (slate, brushed metal, grain) must be Tiled, never stretched.
        private static readonly string[] MustTile = { };
        private const float AspectTolerance = 0.02f;

        [MenuItem("Tools/Audit/Image Slicing")]
        private static void Report()
        {
            var issues = FindIssues();
            string heading = $"Image slicing issues ({issues.Length})";
            if (issues.Length == 0)
                Debug.Log(heading + ": []");
            else
                Debug.LogWarning(heading + ":\n" + string.Join("\n", issues));
        }

        public static string[] FindIssues()
        {
            Canvas.ForceUpdateCanvases();
            var issues = new List<string>();
            for (int i = 0; i < SceneManager.sceneCount; i++)
            {
                var scene = SceneManager.GetSceneAt(i);
                if (!scene.isLoaded) continue;

                foreach (var root in scene.GetRootGameObjects())
                {
                    foreach (var image in root.GetComponentsInChildren<Image>(true))
                        CheckImage(image, issues);
                }
            }
            return issues.ToArray();
        }

        private static void CheckImage(Image image, List<string> issues)
        {
            var sprite = image.overrideSprite;
            if (sprite == null) return;
            var asset = AssetDatabase.GetAssetPath(sprite);
            if (!asset.StartsWith(ArtRoot, StringComparison.Ordinal)) return;

            var rect = image.rectTransform.rect;
            var native = sprite.rect;
            var border = sprite.border;
            if (RequiresTiling(asset) && (image.type != Image.Type.Tiled || border == Vector4.zero))
            {
                issues.Add($"{PathOf(image.transform)} needs a tiled center and fixed borders ({asset})");
                return;
            }

            if (rect.width <= 0 || rect.height <= 0)
            {
                issues.Add($"{PathOf(image.transform)} has an empty rect ({asset})");
                return;
            }

            var error = Mathf.Abs(rect.width * native.height / (rect.height * native.width) - 1);
            bool sliced = image.type == Image.Type.Sliced || image.type == Image.Type.Tiled;
            if (error > AspectTolerance && (!sliced || border == Vector4.zero))
            {
                issues.Add($"{PathOf(image.transform)} {error:P1} aspect mismatch, {image.type}, border {border} ({asset})");
                return;
            }

            if (!sliced) return;
            float pixelsPerUnit = image.pixelsPerUnit * image.pixelsPerUnitMultiplier;
            float minimumWidth = (border.x + border.z) / pixelsPerUnit;
            float minimumHeight = (border.y + border.w) / pixelsPerUnit;
            if (rect.width < minimumWidth || rect.height < minimumHeight)
                issues.Add($"{PathOf(image.transform)} compresses its slice borders ({asset})");
        }

        private static bool RequiresTiling(string asset)
        {
            return Array.IndexOf(MustTile, asset) >= 0;
        }

        private static string PathOf(Transform node)
        {
            return node.parent == null ? node.name : PathOf(node.parent) + "/" + node.name;
        }
    }
}
